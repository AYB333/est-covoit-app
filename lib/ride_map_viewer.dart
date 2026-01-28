import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class RideMapViewer extends StatelessWidget {
  final List<LatLng> polylinePoints;
  final String driverName;
  final String? phone;
  final String price;
  final DateTime date;

  const RideMapViewer({
    super.key,
    required this.polylinePoints,
    required this.driverName,
    required this.phone,
    required this.price,
    required this.date,
  });

  // Coordinates for EST Agadir (Destination)
  static const LatLng _estAgadirLocation = LatLng(30.4070, -9.5790);

  Future<void> _launchWhatsApp(BuildContext context) async {
    if (phone == null || phone!.isEmpty) {
      _showSnackBar(context, "Numéro de téléphone introuvable", Colors.redAccent);
      return;
    }

    String formattedPhoneNumber = phone!.trim();
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
    LatLng? startPoint;
    if (polylinePoints.isNotEmpty) {
      startPoint = polylinePoints.first;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Trajet de $driverName'),
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
              if (polylinePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: polylinePoints,
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
                      child: const Icon(Icons.location_on, color: Colors.green, size: 40), // Start Marker
                    ),
                  Marker(
                    point: _estAgadirLocation,
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(Icons.location_on, color: Colors.red, size: 40),
                        Positioned(
                          bottom: 35,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              'EST AGADIR',
                              style: TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ),
                      ],
                    ), // End Marker (EST Agadir)
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
                      'Conducteur: $driverName',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Prix: $price MAD',
                          style: const TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                        Text(
                          'Date: ${DateFormat('dd/MM/yyyy HH:mm').format(date)}',
                          style: const TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _launchWhatsApp(context),
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
          ),
        ],
      ),
    );
  }
}