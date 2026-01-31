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
  final MapController _mapController = MapController();
  
  // Variables State
  LatLng? _pickedLocation;
  String? _departureAddress;
  List<LatLng> _routePoints = [];
  bool _isLoadingMap = false;
  bool _isLoadingPublish = false;

  // Controllers
  final TextEditingController _departureAddressController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  
  DateTime? _selectedDate;
  double _seats = 1;

  // Vehicle type & pricing logic
  String _selectedVehicle = 'Voiture';
  double _routeDistanceKm = 0.0;
  double _minPrice = 0.0;
  double _maxPrice = 0.0;
  double _price = 0.0;
  final double _priceStep = 0.5;

  // Destination: EST Agadir
  static const LatLng _estAgadirLocation = LatLng(30.4070, -9.5790);

  bool get _isEditing => widget.rideId != null;

  @override
  void initState() {
    super.initState();
    
    // Check if it's the default location from HomeScreen
    bool isDefault = (widget.startLocation.latitude == 30.4000 && widget.startLocation.longitude == -9.6000);

    // Initial setup
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

  void _loadRideData() {
    try {
      final data = widget.rideData!;
      
      // 1. Basic Fields
      _departureAddress = data['departureAddress'];
      _departureAddressController.text = _departureAddress ?? '';
      _selectedVehicle = data['vehicleType'] ?? 'Voiture';
      
      // Safe casting for numbers
      _price = (data['price'] as num?)?.toDouble() ?? 0.0;
      _seats = (data['seats'] as num?)?.toDouble() ?? 1.0;
      if (_seats < 1.0) _seats = 1.0; 
      if (_seats > 4.0) _seats = 4.0;
      
      // 2. Date
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
      
      // 3. Location & Route
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

  Future<void> _geocodeLocation(LatLng location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(location.latitude, location.longitude);
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
      _showSnackBar('Erreur connexion carte', Colors.redAccent);
    } finally {
      setState(() => _isLoadingMap = false);
    }
  }

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

  void _handleMapTap(TapPosition tapPosition, LatLng latlng) {
    setState(() => _pickedLocation = latlng);
    _fetchRoute(latlng);
    _geocodeLocation(latlng);
  }

  Future<void> _goToCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      LatLng loc = LatLng(position.latitude, position.longitude);
      _mapController.move(loc, 13.0);
      _handleMapTap(TapPosition(Offset.zero, Offset.zero), loc);
    } catch (_) {}
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2027),
    );
    
    if (picked != null) {
      // ignore: use_build_context_synchronously
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: _selectedDate != null 
          ? TimeOfDay.fromDateTime(_selectedDate!)
          : TimeOfDay.now(),
      );
      
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

  void _showRideDetailsForm() {
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
                      _isEditing ? 'Modifier le trajet' : 'Confirmer les détails du trajet', 
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue[800]), 
                      textAlign: TextAlign.center
                    ),
                    const SizedBox(height: 20),

                    // 1. VEHICULE
                    const Text('Type de véhicule', style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        Expanded(child: RadioListTile<String>(
                          title: const Text('Voiture'), value: 'Voiture', groupValue: _selectedVehicle,
                          activeColor: Colors.deepPurple,
                          onChanged: (val) => update(() { _selectedVehicle = val!; _updatePriceBounds(); })
                        )),
                        Expanded(child: RadioListTile<String>(
                          title: const Text('Moto'), value: 'Moto', groupValue: _selectedVehicle,
                          activeColor: Colors.deepPurple,
                          onChanged: (val) => update(() { _selectedVehicle = val!; _updatePriceBounds(); })
                        )),
                      ],
                    ),

                    // 2. PRIX
                    const Text('Prix du trajet', style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: _price > _minPrice ? () => update(() => _price = (_price - _priceStep).clamp(_minPrice, _maxPrice)) : null
                        ),
                        Expanded(child: Center(child: Text('${_price.toStringAsFixed(1)} MAD', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)))),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                          onPressed: _price < _maxPrice ? () => update(() => _price = (_price + _priceStep).clamp(_minPrice, _maxPrice)) : null
                        ),
                      ],
                    ),
                    Center(child: Text('Prix autorisé : $_minPrice - $_maxPrice MAD', style: const TextStyle(fontSize: 12, color: Colors.grey))),
                    const SizedBox(height: 15),

                    // 4. DATE
                    TextField(
                      controller: _dateController,
                      readOnly: true,
                      onTap: () async {
                        await _selectDate(context);
                        setModalState(() {}); 
                      },
                      decoration: InputDecoration(
                        labelText: 'Date et heure du trajet',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // 5. SIEGES
                    if (_selectedVehicle == 'Voiture') ...[
                      Text('Nombre de sièges: ${_seats.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Slider(
                        value: _seats, min: 1, max: 4, divisions: 3,
                        activeColor: Colors.blue[800],
                        onChanged: (val) => update(() => _seats = val),
                      ),
                    ],

                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoadingPublish ? null : () {
                        Navigator.pop(context);
                        _publishRide();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: _isLoadingPublish 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : Text(_isEditing ? "Enregistrer les modifications" : "Publier le trajet", style: const TextStyle(fontSize: 18, color: Colors.white)),
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

  Future<void> _publishRide() async {
    if (_selectedDate == null || _departureAddress == null) {
      _showSnackBar('Veuillez remplir tous les champs', Colors.redAccent);
      return;
    }

    setState(() => _isLoadingPublish = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        List<Map<String, double>> polylineData = _routePoints
            .map((latlng) => {'latitude': latlng.latitude, 'longitude': latlng.longitude})
            .toList();

        final Map<String, dynamic> rideData = {
          'driverId': user.uid,
          'driverName': user.displayName ?? 'Utilisateur',
          'driverPhotoUrl': user.photoURL,
          'vehicleType': _selectedVehicle,
          'price': _price,
          'seats': _seats.toInt(),
          'date': Timestamp.fromDate(_selectedDate!),
          'startLat': _pickedLocation!.latitude,
          'startLng': _pickedLocation!.longitude,
          'departureAddress': _departureAddress,
          'destinationName': 'EST Agadir',
          'status': 'available',
          'polylinePoints': polylineData,
          'routeDistanceKm': _routeDistanceKm,
        };

        if (_isEditing) {
           rideData['updatedAt'] = FieldValue.serverTimestamp();
           await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update(rideData);
           _showSnackBar('Trajet modifié avec succès !', Colors.green);
        } else {
           rideData['createdAt'] = FieldValue.serverTimestamp();
           await FirebaseFirestore.instance.collection('rides').add(rideData);
           _showSnackBar('Trajet publié avec succès !', Colors.green);
        }

        if (mounted) Navigator.pop(context); // Revenir au Dashboard
      }
    } catch (e) {
      _showSnackBar('Erreur: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoadingPublish = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100.0),
        child: FloatingActionButton(
          onPressed: _goToCurrentLocation,
          backgroundColor: Colors.white,
          child: const Icon(Icons.my_location, color: Colors.blue),
        ),
      ),
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le trajet' : 'Proposer un trajet'), 
        backgroundColor: Colors.blue[700], 
        foregroundColor: Colors.white
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.startLocation,
              initialZoom: 13.0,
              onTap: _handleMapTap,
            ),
            children: [
              TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'),
              if (_routePoints.isNotEmpty)
                PolylineLayer(polylines: [Polyline(points: _routePoints, color: Colors.blue, strokeWidth: 5.0)]),
              MarkerLayer(markers: [
                Marker(point: _estAgadirLocation, child: const Icon(Icons.location_on, color: Colors.blue, size: 40)),
                if (_pickedLocation != null)
                  Marker(point: _pickedLocation!, child: const Icon(Icons.location_pin, color: Colors.red, size: 40)),
              ]),
            ],
          ),
          if (_isLoadingMap) const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
          
          if (_pickedLocation != null)
            Positioned(
              bottom: 20, left: 20, right: 20,
              child: ElevatedButton(
                onPressed: () {
                  _updatePriceBounds();
                  _showRideDetailsForm();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _isEditing ? 'Confirmer les modifications' : 'Confirmer le trajet', 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
              ),
            ),
        ],
      ),
    );
  }
}