import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:est_covoit/screens/ride_details_screen.dart';
import 'find_ride_screen.dart';
import '../config/translations.dart';

class AddRideScreen extends StatefulWidget {
  final bool isDriver;

  const AddRideScreen({super.key, this.isDriver = true});

  @override
  State<AddRideScreen> createState() => _AddRideScreenState();
}

class _AddRideScreenState extends State<AddRideScreen> {
  static const LatLng _estAgadirLocation = LatLng(30.4061, -9.5790);
  static const double _defaultZoom = 12.0;
  
  LatLng _selectedLocation = _estAgadirLocation;
  final MapController _mapController = MapController();
  bool _isLoadingLocation = false;
  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = false;

  Future<void> _getCurrentLocation() async {
    if (_isLoadingLocation) return;
    setState(() => _isLoadingLocation = true);

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Translations.getText(context, 'gps_enable'))),
      );
      await Geolocator.openLocationSettings();
      setState(() => _isLoadingLocation = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoadingLocation = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      setState(() => _isLoadingLocation = false);
      return;
    }

    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Translations.getText(context, 'location_unavailable'))),
        );
        setState(() => _isLoadingLocation = false);
        return;
      }

      LatLng newPos = LatLng(position.latitude, position.longitude);
      _mapController.move(newPos, 16.0);
      setState(() {
        _isLoadingLocation = false;
      });
      _handleMapTap(TapPosition(Offset.zero, Offset.zero), newPos);
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${Translations.getText(context, 'location_error')} $e")),
      );
    }
  }

  Future<void> _fetchRoute(LatLng startPoint) async {
    setState(() {
      _isLoadingRoute = true;
      _routePoints.clear();
    });

    final String osrmApiUrl = 'https://router.project-osrm.org/route/v1/driving/'
        '${startPoint.longitude},${startPoint.latitude};'
        '${_estAgadirLocation.longitude},${_estAgadirLocation.latitude}'
        '?overview=simplified&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(osrmApiUrl)).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> coordinates = data['routes'][0]['geometry']['coordinates'];
        setState(() {
          _routePoints = coordinates
              .map((coord) => LatLng(coord[1], coord[0]))
              .toList();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${Translations.getText(context, 'routing_error')} ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${Translations.getText(context, 'osrm_connection_error')} $e")),
      );
    } finally {
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  void _handleMapTap(TapPosition tapPosition, LatLng latlng) {
    setState(() {
      _selectedLocation = latlng;
    });
    _fetchRoute(latlng);
  }

  void _handleButtonPress() {
    if (widget.isDriver) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RideDetailsScreen(startLocation: _selectedLocation),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FindRideScreen(userPickupLocation: _selectedLocation),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String appBarTitle = widget.isDriver
        ? Translations.getText(context, 'departure_point')
        : Translations.getText(context, 'trip_to_est');
    final String buttonText = widget.isDriver
        ? Translations.getText(context, 'confirm_departure')
        : Translations.getText(context, 'search_btn');
    final scheme = Theme.of(context).colorScheme;
    final Color buttonColor = widget.isDriver ? scheme.primary : scheme.secondary;

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
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
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: _defaultZoom,
              onPositionChanged: (pos, hasGesture) {
                // Removed to prevent marker from moving while dragging
              },
              onTap: _handleMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.est_covoit',
              ),
              // Polyline route from selected location to EST Agadir
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: scheme.primary,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
              // Markers layer
              MarkerLayer(
                markers: [
                  // EST Agadir destination marker (fixed)
                  Marker(
                    point: _estAgadirLocation,
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.location_on, color: scheme.tertiary, size: 40),
                        Positioned(
                          bottom: 35,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.tertiary.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              'EST AGADIR',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Green marker for selected departure point
                  if (_selectedLocation != _estAgadirLocation)
                    Marker(
                      point: _selectedLocation,
                      width: 80,
                      height: 80,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.location_on, color: scheme.secondary, size: 40),
                          Positioned(
                            bottom: 35,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheme.secondary.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            child: Text(
                              Translations.getText(context, 'departure'),
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),

          // GPS button
          Positioned(
            bottom: 100,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: _getCurrentLocation,
              child: _isLoadingLocation
                  ? CircularProgressIndicator(color: scheme.primary)
                  : Icon(Icons.my_location, color: scheme.primary),
            ),
          ),

          // Action button
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: _handleButtonPress,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                padding: const EdgeInsets.all(15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoadingRoute
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      buttonText,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
