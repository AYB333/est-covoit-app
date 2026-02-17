import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/ride.dart';
import '../repositories/ride_repository.dart';
import '../config/translations.dart';

// --- SCREEN: creation/edition dyal trajet (driver) ---
class RideDetailsScreen extends StatefulWidget {
  final LatLng startLocation;
  final String? initialAddress;
  final String? rideId;
  final Map<String, dynamic>? rideData;

  const RideDetailsScreen({
    super.key, 
    required this.startLocation, 
    this.initialAddress,
    this.rideId,
    this.rideData,
  });

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  // --- CONTROLLER DYAL MAP ---
  final MapController _mapController = MapController();
  
  // --- STATE: location + route + loading ---
  LatLng? _pickedLocation;
  String? _departureAddress;
  List<LatLng> _routePoints = [];
  bool _isLoadingMap = false;
  bool _isLoadingPublish = false;
  bool _isLoadingLocation = false;

  // --- CONTROLLERS: inputs text ---
  final TextEditingController _departureAddressController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  
  // --- STATE: date + seats ---
  DateTime? _selectedDate;
  double _seats = 1;

  // --- LOGIC: vehicle + price ---
  String _selectedVehicle = 'Voiture';
  double _routeDistanceKm = 0.0;
  double _minPrice = 0.0;
  double _maxPrice = 0.0;
  double _price = 0.0;
  final double _priceStep = 0.5;

  // --- CONST: destination (EST) ---
  static const LatLng _estAgadirLocation = LatLng(30.4070, -9.5790);

  // --- MODE: edit / create ---
  bool get _isEditing => widget.rideId != null;

  @override
  void initState() {
    super.initState();
    
    // --- INIT: check default location ---
    bool isDefault = (widget.startLocation.latitude == 30.4000 && widget.startLocation.longitude == -9.6000);

    // --- INIT: edit mode wla new ride ---
    if (_isEditing && widget.rideData != null) {
      _pickedLocation = widget.startLocation;
      _loadRideData();
    } else {
      if (isDefault) {
        // Don't show any route or marker initially
        _pickedLocation = null;
      } else {
        _pickedLocation = widget.startLocation;
        if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
          _departureAddress = widget.initialAddress;
          _departureAddressController.text = widget.initialAddress!;
        } else {
          _geocodeLocation(widget.startLocation);
        }
        _fetchRoute(widget.startLocation);
      }
    }
  }

  // --- LOAD DATA: edit mode ---
  void _loadRideData() {
    try {
      final data = widget.rideData!;
      
      // --- BASIC FIELDS ---
      _departureAddress = data['departureAddress'];
      _departureAddressController.text = _departureAddress ?? '';
      _selectedVehicle = data['vehicleType'] ?? 'Voiture';
      
      // --- SAFE CAST DYAL NUMBERS ---
      _price = (data['price'] as num?)?.toDouble() ?? 0.0;
      _seats = (data['seats'] as num?)?.toDouble() ?? 1.0;
      if (_seats < 1.0) _seats = 1.0; 
      if (_seats > 4.0) _seats = 4.0;
      
      // --- DATE ---
      if (data['date'] != null) {
        if (data['date'] is Timestamp) {
          _selectedDate = (data['date'] as Timestamp).toDate();
        } else if (data['date'] is String) {
           try {
             _selectedDate = DateTime.parse(data['date']);
           } catch (_) {}
        }
        
        if (_selectedDate != null) {
           _dateController.text = DateFormat('dd/MM/yyyy HH:mm').format(_selectedDate!);
        }
      }
      
      // --- LOCATION + ROUTE ---
      _fetchRoute(widget.startLocation);
    } catch (e) {
      debugPrint("Error loading ride data: $e");
      _price = 10.0;
      _seats = 4.0;
    }
  }

  @override
  void dispose() {
    _departureAddressController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // --- REVERSE GEOCODING: coords -> address ---
  Future<void> _geocodeLocation(LatLng location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(location.latitude, location.longitude);
      if (!mounted) return;
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        final String address = [
          if ((place.locality ?? '').isNotEmpty) place.locality!,
          if ((place.street ?? '').isNotEmpty) place.street!,
        ].join(', ');

        if (address.isNotEmpty) {
          setState(() {
            _departureAddress = address;
            _departureAddressController.text = address;
          });
        }
      }
    } catch (_) {}
  }

  // --- FETCH ROUTE MEN OSRM ---
  Future<void> _fetchRoute(LatLng startPoint) async {
    setState(() {
      _isLoadingMap = true;
      _routePoints.clear();
    });

    final String osrmApiUrl = 'https://routing.openstreetmap.de/routed-car/route/v1/driving/'
        '${startPoint.longitude},${startPoint.latitude};'
        '${_estAgadirLocation.longitude},${_estAgadirLocation.latitude}'
        '?overview=full&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(osrmApiUrl));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> coordinates = data['routes'][0]['geometry']['coordinates'];
        setState(() {
          _routePoints = coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
          _routeDistanceKm = (data['routes'][0]['distance'] as num) / 1000.0;
        });
        _updatePriceBounds();
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(Translations.getText(context, 'map_connection_error'), Colors.redAccent);
    } finally {
      if (mounted) {
        setState(() => _isLoadingMap = false);
      }
    }
  }

  // --- PRICE BOUNDS 3la 7sab distance + vehicle ---
  void _updatePriceBounds() {
    final bool isMoto = _selectedVehicle == 'Moto';
    final double rate = isMoto ? 0.5 : 1.0;
    double calculatedPrice = _routeDistanceKm * rate;
    if (calculatedPrice < 2.0) calculatedPrice = 2.0;

    double minP = calculatedPrice * 0.8;
    double maxP = calculatedPrice * 1.2;

    minP = (minP * 2).round() / 2;
    maxP = (maxP * 2).round() / 2;

    if (maxP <= minP) maxP = minP + 1.0;

    setState(() {
      _minPrice = minP;
      _maxPrice = maxP;

      if (_price == 0 || _price < _minPrice || _price > _maxPrice) {
        _price = (calculatedPrice * 2).round() / 2;
        if (_price < _minPrice) _price = _minPrice;
        if (_price > _maxPrice) _price = _maxPrice;
      }

      if (isMoto) _seats = 1;
    });
  }

  // --- MAP TAP: n9tar location w n7edd route ---
  void _handleMapTap(TapPosition tapPosition, LatLng latlng) {
    setState(() => _pickedLocation = latlng);
    _fetchRoute(latlng);
    _geocodeLocation(latlng);
  }

  // --- GPS: jibi current location ---
  Future<void> _goToCurrentLocation() async {
    if (_isLoadingLocation) return;
    try {
      setState(() => _isLoadingLocation = true);

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) {
        _showSnackBar(Translations.getText(context, 'gps_enable'), Colors.redAccent);
        await Geolocator.openLocationSettings();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted) return;
      }

      if (permission == LocationPermission.denied) {
        _showSnackBar(Translations.getText(context, 'location_permission_denied'), Colors.redAccent);
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar(Translations.getText(context, 'location_permission_denied_forever'), Colors.redAccent);
        await Geolocator.openAppSettings();
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        if (!mounted) return;
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
        if (!mounted) return;
      }

      if (position == null) {
        _showSnackBar(Translations.getText(context, 'location_unavailable'), Colors.redAccent);
        return;
      }

      LatLng loc = LatLng(position.latitude, position.longitude);
      _mapController.move(loc, 13.0);
      _handleMapTap(TapPosition(Offset.zero, Offset.zero), loc);
    } catch (e) {
      _showSnackBar("${Translations.getText(context, 'location_error')} $e", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  // --- PICK DATE + TIME ---
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2027),
    );
    
    if (picked != null) {
      if (!context.mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: _selectedDate != null 
          ? TimeOfDay.fromDateTime(_selectedDate!)
          : TimeOfDay.now(),
      );
      if (!context.mounted) return;
      
      if (pickedTime != null) {
        final DateTime fullDate = DateTime(
          picked.year, picked.month, picked.day, 
          pickedTime.hour, pickedTime.minute
        );
        
        setState(() {
          _selectedDate = fullDate;
          _dateController.text = DateFormat('dd/MM/yyyy HH:mm').format(fullDate);
        });
      }
    }
  }

  // --- BOTTOM SHEET: form dyal details ---
  void _showRideDetailsForm() {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            void update(VoidCallback fn) {
              setModalState(fn);
              setState(fn);
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20, right: 20, top: 20
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isEditing
                          ? Translations.getText(context, 'trip_edit_title')
                          : Translations.getText(context, 'trip_confirm_details'),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: scheme.primary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // --- 1) no3 l-vehicle ---
                    Text(
                      Translations.getText(context, 'vehicle_type'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    RadioGroup<String>(
                      groupValue: _selectedVehicle,
                      onChanged: (value) {
                        if (value == null) return;
                        update(() {
                          _selectedVehicle = value;
                          _updatePriceBounds();
                        });
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: Text(Translations.getText(context, 'vehicle_car')),
                              value: 'Voiture',
                              activeColor: scheme.primary,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: Text(Translations.getText(context, 'vehicle_moto')),
                              value: 'Moto',
                              activeColor: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- 2) thaman ---
                    Text(
                      Translations.getText(context, 'trip_price'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline, color: scheme.error),
                          onPressed: _price > _minPrice ? () => update(() => _price = (_price - _priceStep).clamp(_minPrice, _maxPrice)) : null
                        ),
                        Expanded(child: Center(child: Text('${_price.toStringAsFixed(1)} MAD', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)))),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline, color: scheme.secondary),
                          onPressed: _price < _maxPrice ? () => update(() => _price = (_price + _priceStep).clamp(_minPrice, _maxPrice)) : null
                        ),
                      ],
                    ),
                    Center(
                      child: Text(
                        "${Translations.getText(context, 'allowed_price')}: $_minPrice - $_maxPrice MAD",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // --- 3) date + time ---
                    TextField(
                      controller: _dateController,
                      readOnly: true,
                      onTap: () async {
                        await _selectDate(context);
                        setModalState(() {}); 
                      },
                      decoration: InputDecoration(
                        labelText: Translations.getText(context, 'trip_date_time'),
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // --- 4) seats (car only) ---
                    if (_selectedVehicle == 'Voiture') ...[
                      Text(
                        "${Translations.getText(context, 'seats_count')}: ${_seats.toInt()}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Slider(
                        value: _seats, min: 1, max: 4, divisions: 3,
                        activeColor: scheme.primary,
                        onChanged: (val) => update(() => _seats = val),
                      ),
                    ],

                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoadingPublish ? null : () {
                        Navigator.pop(context);
                        _publishRide();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: scheme.primary, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: _isLoadingPublish 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : Text(
                            _isEditing
                                ? Translations.getText(context, 'save_changes')
                                : Translations.getText(context, 'publish_journey'),
                            style: const TextStyle(fontSize: 18, color: Colors.white),
                          ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- SAVE / UPDATE f Firestore ---
  Future<void> _publishRide() async {
    if (_selectedDate == null || _departureAddress == null) {
      _showSnackBar(Translations.getText(context, 'error_fill_fields'), Colors.redAccent);
      return;
    }

    setState(() => _isLoadingPublish = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
                final ride = Ride(
          id: widget.rideId ?? '',
          driverId: user.uid,
          driverName: user.displayName ?? Translations.getText(context, 'user'),
          driverPhotoUrl: user.photoURL,
          vehicleType: _selectedVehicle,
          price: _price,
          seats: _seats.toInt(),
          date: _selectedDate!,
          startLat: _pickedLocation!.latitude,
          startLng: _pickedLocation!.longitude,
          departureAddress: _departureAddress,
          destinationName: 'EST Agadir',
          status: 'available',
          polylinePoints: _routePoints,
          routeDistanceKm: _routeDistanceKm,
        );

        final repo = RideRepository();
        if (_isEditing) {
           await repo.updateRide(widget.rideId!, ride);
           if (!mounted) return;
           _showSnackBar(Translations.getText(context, 'trip_modified_success'), Colors.green);
        } else {
           await repo.createRide(ride);
           if (!mounted) return;
           _showSnackBar(Translations.getText(context, 'trip_published_success'), Colors.green);
        }
if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar("${Translations.getText(context, 'error_prefix')} $e", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoadingPublish = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      // --- GPS FLOATING BUTTON ---
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100.0),
        child: FloatingActionButton(
          onPressed: _goToCurrentLocation,
          backgroundColor: scheme.surface,
          child: _isLoadingLocation
              ? CircularProgressIndicator(color: scheme.primary)
              : Icon(Icons.my_location, color: scheme.primary),
        ),
      ),
      // --- APPBAR ---
      appBar: AppBar(
        title: Text(
          _isEditing
              ? Translations.getText(context, 'trip_edit_title')
              : Translations.getText(context, 'propose_trip'),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      // --- BODY: map + confirm button ---
      body: Stack(
        children: [
          // --- MAP VIEW ---
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.startLocation,
              initialZoom: _pickedLocation == null ? 12.0 : 13.0,
              onTap: _handleMapTap,
            ),
            children: [
              // --- MAP TILES ---
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.est_covoit',
              ),
              // --- ROUTE POLYLINE ---
              if (_routePoints.isNotEmpty)
                PolylineLayer(polylines: [Polyline(points: _routePoints, color: scheme.primary, strokeWidth: 5.0)]),
              // --- MARKERS ---
              MarkerLayer(markers: [
                Marker(point: _estAgadirLocation, child: Icon(Icons.location_on, color: scheme.tertiary, size: 40)),
                if (_pickedLocation != null)
                  Marker(point: _pickedLocation!, child: Icon(Icons.location_pin, color: scheme.secondary, size: 40)),
              ]),
            ],
          ),
          // --- LOADING OVERLAY ---
          if (_isLoadingMap) Center(child: CircularProgressIndicator(color: scheme.primary)),
          
          // --- CONFIRM BUTTON (open form) ---
          if (_pickedLocation != null)
            Positioned(
              bottom: 20, left: 20, right: 20,
              child: ElevatedButton(
                onPressed: () {
                  _updatePriceBounds();
                  _showRideDetailsForm();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _isEditing
                      ? Translations.getText(context, 'confirm_changes')
                      : Translations.getText(context, 'confirm_journey'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

