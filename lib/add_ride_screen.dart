import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart'; // Darouri l-GPS
import 'ride_details_screen.dart';

class AddRideScreen extends StatefulWidget {
  const AddRideScreen({super.key});

  @override
  State<AddRideScreen> createState() => _AddRideScreenState();
}

class _AddRideScreenState extends State<AddRideScreen> {
  // Par défaut: Agadir
  LatLng _selectedLocation = const LatLng(30.4061, -9.5544);
  final MapController _mapController = MapController();
  bool _isLoadingLocation = false;

  // Fonction Bach Njibo L-Localisation Actuelle
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    bool serviceEnabled;
    LocationPermission permission;

    // 1. Wach GPS ch3al?
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez activer le GPS')));
      setState(() => _isLoadingLocation = false);
      return;
    }

    // 2. Vérifier Permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoadingLocation = false);
        return;
      }
    }

    // 3. Jib l-Position
    Position position = await Geolocator.getCurrentPosition();
    
    // 4. 7errek l-Map l-tmma
    LatLng newPos = LatLng(position.latitude, position.longitude);
    _mapController.move(newPos, 16.0);
    
    setState(() {
      _selectedLocation = newPos;
      _isLoadingLocation = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Point de départ")),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 15.0,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture && pos.center != null) {
                  setState(() => _selectedLocation = pos.center!);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.est_covoit',
              ),
            ],
          ),
          
          // Marker Fixe
          const Center(child: Icon(Icons.location_on, color: Colors.red, size: 50)),

          // BOUTON GPS (Jdid)
          Positioned(
            bottom: 100, // Fouq l-bouton l-kbir chwiya
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: _getCurrentLocation,
              child: _isLoadingLocation 
                ? const CircularProgressIndicator(color: Colors.blue) 
                : const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),

          // Bouton Confirmer
          Positioned(
            bottom: 30, left: 20, right: 20,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RideDetailsScreen(startLocation: _selectedLocation),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], padding: const EdgeInsets.all(15)),
              child: const Text("Confirmer le départ", style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}