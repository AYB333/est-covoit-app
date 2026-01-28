import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RideDetailsScreen extends StatefulWidget {
  final LatLng startLocation;

  const RideDetailsScreen({super.key, required this.startLocation});

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  final MapController _mapController = MapController();
  LatLng? _pickedLocation;
  List<LatLng> _routePoints = [];
  bool _isLoadingMap = false;
  bool _isLoadingPublish = false;

  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  DateTime? _selectedDate;
  double _seats = 1;

  static const LatLng _estAgadirLocation = LatLng(30.3986, -9.5532);

  @override
  void dispose() {
    _priceController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Future<void> _fetchRoute(LatLng startPoint) async {
    setState(() {
      _isLoadingMap = true;
      _routePoints.clear();
    });

    final String osrmApiUrl = 'http://router.project-osrm.org/route/v1/driving/'
        '${startPoint.longitude},${startPoint.latitude};'
        '${_estAgadirLocation.longitude},${_estAgadirLocation.latitude}'
        '?overview=full&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(osrmApiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> coordinates = data['routes'][0]['geometry']['coordinates'];
        setState(() {
          _routePoints = coordinates
              .map((coord) => LatLng(coord[1], coord[0]))
              .toList();
        });
      } else {
        _showSnackBar('Erreur de routage: ${response.statusCode}', Colors.redAccent);
      }
    } catch (e) {
      _showSnackBar('Erreur de connexion OSRM: ${e.toString()}', Colors.redAccent);
    } finally {
      setState(() {
        _isLoadingMap = false;
      });
    }
  }

  void _handleMapTap(TapPosition tapPosition, LatLng latlng) {
    setState(() {
      _pickedLocation = latlng;
    });
    _fetchRoute(latlng);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2027),
    );
    if (picked != null && picked != _selectedDate) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _publishRide() async {
    if (_priceController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _selectedDate == null ||
        _pickedLocation == null ||
        _routePoints.isEmpty) {
      _showSnackBar('Veuillez sélectionner un point de départ et remplir tous les champs.', Colors.redAccent);
      return;
    }

    setState(() {
      _isLoadingPublish = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnackBar('Vous devez être connecté pour publier un trajet.', Colors.redAccent);
        setState(() {
          _isLoadingPublish = false;
        });
        return;
      }

      List<Map<String, double>> polylineData = _routePoints
          .map((latlng) => {'latitude': latlng.latitude, 'longitude': latlng.longitude})
          .toList();

      await FirebaseFirestore.instance.collection('rides').add({
        'driverId': user.uid,
        'driverName': user.displayName ?? user.email ?? 'Utilisateur Inconnu',
        'phone': _phoneController.text,
        'price': double.parse(_priceController.text),
        'seats': _seats.toInt(),
        'date': Timestamp.fromDate(_selectedDate!),
        'startLat': _pickedLocation!.latitude,
        'startLng': _pickedLocation!.longitude,
        'destinationLat': _estAgadirLocation.latitude,
        'destinationLng': _estAgadirLocation.longitude,
        'destinationName': 'EST Agadir',
        'status': 'available',
        'createdAt': FieldValue.serverTimestamp(),
        'polylinePoints': polylineData,
      });

      if (!mounted) return;
      _showSnackBar('Trajet publié avec succès !', Colors.green);
      Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      _showSnackBar('Erreur Firebase: ${e.message}', Colors.redAccent);
    } catch (e) {
      _showSnackBar('Erreur: ${e.toString()}', Colors.redAccent);
    } finally {
      setState(() {
        _isLoadingPublish = false;
      });
    }
  }

  void _showRideDetailsForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Confirmer les détails du trajet',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Prix (MAD)',
                  prefixIcon: const Icon(Icons.money),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Numéro de téléphone',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 15),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: AbsorbPointer(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: _selectedDate == null
                          ? 'Date et heure du trajet'
                          : DateFormat('dd/MM/yyyy HH:mm').format(_selectedDate!),
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nombre de sièges: ${_seats.toInt()}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: _seats,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: _seats.toInt().toString(),
                    onChanged: (value) {
                      setState(() {
                        _seats = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoadingPublish ? null : _publishRide,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: _isLoadingPublish
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Publier le trajet'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proposer un trajet'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _estAgadirLocation,
              initialZoom: 13.0,
              onTap: _handleMapTap,
            ),
            children: [
              TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'),
              if (_pickedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _pickedLocation!,
                      width: 80,
                      height: 80,
                      child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                    ),
                  ],
                ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.blue,
                      strokeWidth: 5.0,
                    ),
                  ],

                ),

            ],

          ),

          if (_isLoadingMap)

            const Center(

              child: CircularProgressIndicator(color: Colors.blueAccent),

            ),

          if (_pickedLocation != null && _routePoints.isNotEmpty)

            Positioned(

              bottom: 20,

              left: 20,

              right: 20,

              child: ElevatedButton(

                onPressed: _showRideDetailsForm,

                style: ElevatedButton.styleFrom(

                  backgroundColor: Colors.green,

                  foregroundColor: Colors.white,

                  padding: const EdgeInsets.symmetric(vertical: 16),

                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),

                ),

                child: const Text('Confirmer le trajet'),

              ),

            ),

        ],

      ),

    );

  }

}