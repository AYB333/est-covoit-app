import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'ride_map_viewer.dart'; // Import the new map viewer screen
import 'package:firebase_auth/firebase_auth.dart';

class FindRideScreen extends StatefulWidget {
  final LatLng? userPickupLocation;

  const FindRideScreen({super.key, this.userPickupLocation});

  @override
  State<FindRideScreen> createState() => _FindRideScreenState();
}

class _FindRideScreenState extends State<FindRideScreen> {
  void _showSnackBar(BuildContext context, String message, Color color) {
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

  @override
  Widget build(BuildContext context) {
    final LatLng? pickup = widget.userPickupLocation;

    if (pickup == null) {
      return  Scaffold(
        appBar: AppBar(title: Text('Trajets Disponibles')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final double userLat = pickup.latitude;
    final double userLng = pickup.longitude;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trajets Disponibles'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Filter rides where the 'date' field is greater than or equal to the current date/time
        stream: FirebaseFirestore.instance
            .collection('rides')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 2))))
            .orderBy('date', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car_outlined, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text('Aucun trajet disponible pour le moment.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final allRides = snapshot.data!.docs;

          // Simple filter: Show all active trips going to EST Agadir
          final filteredRides = allRides.where((ride) {
            final data = ride.data() as Map<String, dynamic>;
            final String destination = (data['destinationName'] ?? '').toString().toLowerCase();
            
            // Accept trips that have "agadir" or "est" in the destination
            return destination.contains('agadir') || destination.contains('est');
          }).toList();

          if (filteredRides.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car_outlined, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text('Aucun trajet vers EST Agadir pour le moment.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final currentUserUid = FirebaseAuth.instance.currentUser?.uid;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: filteredRides.length,
            itemBuilder: (context, index) {
              final ride = filteredRides[index];
              final data = ride.data() as Map<String, dynamic>;

              String formattedDate = "Date inconnue";
              try {
                if (data['date'] != null && data['date'] is Timestamp) {
                  formattedDate = DateFormat('dd/MM/yyyy HH:mm').format((data['date'] as Timestamp).toDate());
                }
              } catch (e) {
                formattedDate = "Erreur date";
              }

              String driverName = data['driverName']?.toString() ?? "Inconnu";
              String destinationName = data['destinationName']?.toString() ?? "EST Agadir";
              // Get departure address with fallback to coordinates
              String departureCity = data['departureAddress']?.toString() ?? 
                  "${(data['startLat'] as num?)?.toStringAsFixed(2) ?? '?'}, ${(data['startLng'] as num?)?.toStringAsFixed(2) ?? '?'}";
              String price = data['price']?.toString() ?? "?";
              String seats = data['seats']?.toString() ?? "0";
              String? phone = data['phone']?.toString();
              DateTime rideDate = (data['date'] as Timestamp).toDate();
              
              List<LatLng> polylinePoints = [];
              if (data['polylinePoints'] != null) {
                polylinePoints = (data['polylinePoints'] as List<dynamic>)
                    .map((p) => LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble()))
                    .toList();
              }

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 10.0),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => RideMapViewer(
                          polylinePoints: polylinePoints,
                          driverName: driverName,
                          phone: phone,
                          price: price,
                          date: rideDate,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Conducteur: $driverName',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(10)),
                                      child: Text('$price MAD', style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 8),
                                    if (currentUserUid == data['driverId'])
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () async {
                                          final bool? confirmDelete = await showDialog<bool>(
                                            context: context,
                                            builder: (BuildContext dialogContext) {
                                              return AlertDialog(
                                                title: const Text('Supprimer le trajet ?'),
                                                content: const Text('Voulez-vous vraiment supprimer ce trajet ?'),
                                                actions: <Widget>[
                                                  TextButton(
                                                    onPressed: () => Navigator.of(dialogContext).pop(false),
                                                    child: const Text('Annuler'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () => Navigator.of(dialogContext).pop(true),
                                                    child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                                                  ),
                                                ],
                                              );
                                            },
                                          );

                                          if (confirmDelete == true) {
                                            try {
                                              await FirebaseFirestore.instance.collection('rides').doc(ride.id).delete();
                                              _showSnackBar(context, 'Trajet supprimé avec succès !', Colors.green);
                                            } catch (e) {
                                              _showSnackBar(context, 'Erreur lors de la suppression: ${e.toString()}', Colors.redAccent);
                                            }
                                          }
                                        },
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            
                            // Prominent route display
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blue[200]!, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'De:',
                                          style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                                        ),
                                        Text(
                                          departureCity,
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward, color: Colors.blue[600]),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'À:',
                                          style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                                        ),
                                        Text(
                                          destinationName,
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            _buildDetailRow(Icons.calendar_today, 'Date: $formattedDate'),
                            _buildDetailRow(Icons.event_seat, 'Sièges disponibles: $seats'),

                            const SizedBox(height: 15),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '📍 Voir le trajet sur la carte',
                                style: TextStyle(color: Colors.blue[600], fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15, color: Colors.black87))),
        ],
      ),
    );
  }
}