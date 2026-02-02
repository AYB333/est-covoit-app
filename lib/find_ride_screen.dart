import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'ride_map_viewer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_avatar.dart';
import 'translations.dart';
import 'booking_service.dart';


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
        appBar: AppBar(title: Text(Translations.getText(context, 'available_trips'))),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final double userLat = pickup.latitude;
    final double userLng = pickup.longitude;

    return Scaffold(
      appBar: AppBar(
        title: Text(Translations.getText(context, 'available_trips')),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Filter rides where the 'date' field is greater than or equal to the current date/time
        stream: FirebaseFirestore.instance
            .collection('rides')
            // Relaxed filter: Show rides from last 24 hours
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))))
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.directions_car_outlined, size: 60, color: Colors.grey),
                  const SizedBox(height: 10),
                  Text(Translations.getText(context, 'no_trips'), style: const TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final allRides = snapshot.data!.docs;
          final Distance distanceCalculator = const Distance();

          // Filter rides that pass near the user (within 3 km radius)
          final filteredRides = allRides.where((ride) {
            final data = ride.data() as Map<String, dynamic>;
            
            // 1. Check if potential route points exist
            List<dynamic> rawPoints = data['polylinePoints'] ?? [];
            if (rawPoints.isEmpty) {
              // Fallback: Check start location distance if no route data
              double startLat = (data['startLat'] as num?)?.toDouble() ?? 0.0;
              double startLng = (data['startLng'] as num?)?.toDouble() ?? 0.0;
              if (startLat != 0 && startLng != 0) {
                 return distanceCalculator.as(LengthUnit.Meter, pickup, LatLng(startLat, startLng)) < 800;
              }
              return false;
            }

            // 2. Check if ANY point on the route is close to user
            // Optimization: radius reduced to 800m for better accuracy
            for (var p in rawPoints) {
              final double lat = (p['latitude'] as num).toDouble();
              final double lng = (p['longitude'] as num).toDouble();
              final double distInfo = distanceCalculator.as(LengthUnit.Meter, pickup, LatLng(lat, lng));
              
              if (distInfo < 800) { // 800 meters tolerance
                return true; 
              }
            }
            
            return false;
          }).toList();

          if (filteredRides.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.commute_outlined, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 20),
                    const Text(
                      'Aucun trajet ne passe par votre position.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Essayez de vous rapprocher d\'une route principale.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
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

                  final bool isMyRide = currentUserUid == data['driverId'];
                  final String vehicleType = data['vehicleType'] ?? 'Voiture';
                  final int availableSeats = int.tryParse(data['seats'].toString()) ?? 0;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 10.0),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header: Driver + Price + Vehicle Icon
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      UserAvatar(
                                        userName: driverName,
                                        imageUrl: data['driverPhotoUrl'],
                                        radius: 20,
                                        backgroundColor: Colors.blue[100],
                                        textColor: Colors.blue[800],
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            driverName,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                          Row(
                                            children: [
                                              Icon(
                                                vehicleType == 'Moto' ? Icons.two_wheeler : Icons.directions_car,
                                                size: 14,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(vehicleType, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      '$price MAD',
                                      style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const Divider(height: 25),
                              
                              // Route
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Départ', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                        Text(departureCity, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Icon(Icons.arrow_forward, color: Colors.blue[300]),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('Arrivée', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                        Text(destinationName, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 15),

                              // Info Grid
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 5),
                                      Text(formattedDate, style: TextStyle(color: Colors.grey[800])),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Icon(Icons.event_seat, size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 5),
                                      Text(
                                        '$seats place(s)',
                                        style: TextStyle(
                                          color: availableSeats > 0 ? Colors.grey[800] : Colors.red,
                                          fontWeight: availableSeats > 0 ? FontWeight.normal : FontWeight.bold
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Actions
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => RideMapViewer(
                                              polylinePoints: polylinePoints,
                                              driverName: driverName,
                                              phone: phone,
                                              price: price,
                                              date: rideDate,
                                              rideId: ride.id,
                                              rideData: data,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.map, size: 18),
                                      label: const Text("Voir Carte"),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.blue,
                                        side: const BorderSide(color: Colors.blue),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  if (!isMyRide)
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: availableSeats > 0 
                                          ? () => _reserveRide(context, ride.id, data) 
                                          : null,
                                        icon: const Icon(Icons.bookmark_add, size: 18),
                                        label: const Text("Réserver"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue[700],
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor: Colors.grey[300],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        // COMPLET OVERLAY
                        if (availableSeats == 0)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Center(
                                child: Transform.rotate(
                                  angle: -0.2, // Slightly tilted
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.red, width: 4),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      "COMPLET",
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 4,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
        },
      ),
    );
  }

  Future<void> _reserveRide(BuildContext context, String rideId, Map<String, dynamic> rideData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar(context, "Vous devez être connecté.", Colors.red);
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

    final result = await BookingService.reserveRide(
      user: user,
      rideId: rideId,
      rideData: rideData,
    );

    if (!context.mounted) return;
    final Color color = switch (result.status) {
      BookingCreateStatus.success => Colors.green,
      BookingCreateStatus.alreadyExists => Colors.orange,
      _ => Colors.red,
    };
    _showSnackBar(context, result.message, color);
  }
}
