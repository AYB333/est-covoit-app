import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RideMapViewer extends StatefulWidget {
  final List<LatLng> polylinePoints;
  final String driverName;
  final String? phone;
  final String price;
  final DateTime date;
  
  // New fields for reservation logic
  final String? rideId;
  final Map<String, dynamic>? rideData;

  const RideMapViewer({
    super.key,
    required this.polylinePoints,
    required this.driverName,
    required this.phone,
    required this.price,
    required this.date,
    this.rideId,
    this.rideData,
  });

  @override
  State<RideMapViewer> createState() => _RideMapViewerState();
}

class _RideMapViewerState extends State<RideMapViewer> {
  static const LatLng _estAgadirLocation = LatLng(30.4070, -9.5790);

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _reserveRide() async {
    if (widget.rideId == null || widget.rideData == null) {
      _showSnackBar("Erreur: Données du trajet manquantes.", Colors.red);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar("Vous devez être connecté.", Colors.red);
      return;
    }

    // Confirmation Dialog
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmer la réservation"),
        content: const Text("Voulez-vous envoyer une demande de réservation au conducteur ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Confirmer"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Check if already reserved
      final existing = await FirebaseFirestore.instance
          .collection('bookings')
          .where('rideId', isEqualTo: widget.rideId)
          .where('passengerId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        if (!context.mounted) return;
        _showSnackBar("Vous avez déjà réservé ce trajet.", Colors.orange);
        return;
      }

      // Add Booking
      await FirebaseFirestore.instance.collection('bookings').add({
        'rideId': widget.rideId,
        'driverId': widget.rideData!['driverId'],
        'passengerId': user.uid,
        'passengerName': user.displayName ?? user.email?.split('@')[0] ?? 'Passager',
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'rideDestination': widget.rideData!['destinationName'] ?? 'EST Agadir',
        'rideDate': widget.rideData!['date'],
        'ridePrice': widget.rideData!['price'],
        'driverName': widget.rideData!['driverName'],
        'driverPhone': widget.rideData!['phone'],
        'departureAddress': widget.rideData!['departureAddress'],
      });

      if (!context.mounted) return;
      _showSnackBar("Demande envoyée ! En attente d'acceptation.", Colors.green);

    } catch (e) {
      if (!context.mounted) return;
      _showSnackBar("Erreur: $e", Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    LatLng? startPoint;
    if (widget.polylinePoints.isNotEmpty) {
      startPoint = widget.polylinePoints.first;
    }

    // Check if current user is the driver
    final user = FirebaseAuth.instance.currentUser;
    final bool isMyRide = (user != null && widget.rideData != null && user.uid == widget.rideData!['driverId']);
    final int seats = (widget.rideData != null && widget.rideData!['seats'] is num) 
        ? (widget.rideData!['seats'] as num).toInt() 
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Trajet de ${widget.driverName}'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: startPoint ?? _estAgadirLocation,
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'),
              if (widget.polylinePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: widget.polylinePoints,
                      color: Colors.blue,
                      strokeWidth: 5.0,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (startPoint != null)
                    Marker(
                      point: startPoint,
                      width: 80,
                      height: 80,
                      child: const Icon(Icons.location_on, color: Colors.green, size: 40),
                    ),
                  Marker(
                    point: _estAgadirLocation,
                    width: 80,
                    height: 80,
                    child: const Icon(Icons.school, color: Colors.red, size: 40),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conducteur: ${widget.driverName}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Prix: ${widget.price} MAD', style: const TextStyle(fontSize: 16, color: Colors.black87)),
                        Text('Date: ${DateFormat('dd/MM HH:mm').format(widget.date)}', style: const TextStyle(fontSize: 16, color: Colors.black87)),
                      ],
                    ),
                    
                    if (!isMyRide && widget.rideData != null) ...[
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: seats > 0 ? _reserveRide : null,
                          icon: const Icon(Icons.bookmark_added, color: Colors.white),
                          label: Text(
                            seats > 0 ? 'Réserver ce trajet' : 'Complet', 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: seats > 0 ? Colors.blue[700] : Colors.grey,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}