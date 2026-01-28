import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

class FindRideScreen extends StatelessWidget {
  const FindRideScreen({super.key});

  Future<void> _launchWhatsApp(BuildContext context, String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      _showSnackBar(context, "Numéro de téléphone introuvable", Colors.red);
      return;
    }

    String formattedPhoneNumber = phoneNumber.trim();
    if (formattedPhoneNumber.startsWith('0')) {
      formattedPhoneNumber = '+212${formattedPhoneNumber.substring(1)}';
    } else if (!formattedPhoneNumber.startsWith('+')) {
      formattedPhoneNumber = '+212$formattedPhoneNumber';
    }

    final Uri url = Uri.parse('https://wa.me/$formattedPhoneNumber');
    
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Impossible de lancer WhatsApp';
      }
    } catch (e) {
      print("Erreur WhatsApp: $e");
      _showSnackBar(context, 'Erreur: WhatsApp n\'est pas installé ou lien invalide', Colors.redAccent);
    }
  }

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
        stream: FirebaseFirestore.instance.collection('rides').orderBy('date', descending: false).snapshots(),
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
              
              // Hna l-code kay-jbed l-points d l-map wakha ma-kysta3mlhoumch daba (Mzyan)
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
                    // Mba3d n-qddo ndiro navigation hna bach y-chouf l-Map
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Conducteur: $driverName',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(10)),
                              child: Text('$price MAD', style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        
                        // Détails
                        _buildDetailRow(Icons.location_on, 'De: ${startLat.toStringAsFixed(4)}, ${startLng.toStringAsFixed(4)}'),
                        _buildDetailRow(Icons.location_city, 'À: $destinationName'),
                        _buildDetailRow(Icons.calendar_today, 'Date: $formattedDate'),
                        _buildDetailRow(Icons.event_seat, 'Sièges disponibles: $seats'),

                        const SizedBox(height: 15),
                        
                        // Bouton WhatsApp (CORRIGÉ)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _launchWhatsApp(context, phone),
                            // HNA FIN KAN L-GHLAT: Rddina Icons.whatsapp -> Icons.message
                            icon: const Icon(Icons.message, color: Colors.white), 
                            label: const Text('Contacter sur WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
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