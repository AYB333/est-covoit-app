import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:est_covoit/ride_map_viewer.dart'; // Import the new map viewer screen

class FindRideScreen extends StatelessWidget {
  const FindRideScreen({super.key});

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

              final rides = snapshot.data!.docs;
              final currentUserUid = FirebaseAuth.instance.currentUser?.uid; // Get current user UID

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: rides.length,
            itemBuilder: (context, index) {
              final ride = rides[index];
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
              String price = data['price']?.toString() ?? "?";
              String seats = data['seats']?.toString() ?? "0";
              double startLat = (data['startLat'] as num?)?.toDouble() ?? 0.0;
              double startLng = (data['startLng'] as num?)?.toDouble() ?? 0.0;
              String? phone = data['phone']?.toString();
              DateTime rideDate = (data['date'] as Timestamp).toDate();
              
              List<LatLng> polylinePoints = [];
              if (data['polylinePoints'] != null) {
                polylinePoints = (data['polylinePoints'] as List<dynamic>)
                    .map((p) => LatLng(p['latitude'] as double, p['longitude'] as double))
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
                            
                            _buildDetailRow(Icons.location_on, 'De: Point de départ'),
                            _buildDetailRow(Icons.location_city, 'À: $destinationName'),
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