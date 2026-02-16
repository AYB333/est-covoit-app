import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:est_covoit/screens/ride_map_viewer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/user_avatar.dart';
import '../config/translations.dart';
import '../services/booking_service.dart';
import '../models/ride.dart';
import '../repositories/ride_repository.dart';


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

  String _bookingMessage(BookingCreateResult result) {
    switch (result.status) {
      case BookingCreateStatus.success:
        return Translations.getText(context, 'booking_request_sent');
      case BookingCreateStatus.alreadyExists:
        return Translations.getText(context, 'booking_already_exists');
      case BookingCreateStatus.invalidData:
        return Translations.getText(context, 'booking_invalid_data');
      case BookingCreateStatus.error:
      default:
        return Translations.getText(context, 'booking_error_generic');
    }
  }

  @override
  Widget build(BuildContext context) {
    final LatLng? pickup = widget.userPickupLocation;
    final scheme = Theme.of(context).colorScheme;

    if (pickup == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(Translations.getText(context, 'available_trips')),
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
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final double userLat = pickup.latitude;
    final double userLng = pickup.longitude;

    return Scaffold(
      appBar: AppBar(
        title: Text(Translations.getText(context, 'available_trips')),
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
      body: StreamBuilder<List<Ride>>(
        // Filter rides where the 'date' field is greater than or equal to the current date/time
        stream: RideRepository().streamAvailableRidesFrom(
          DateTime.now().subtract(const Duration(days: 1)),
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text("${Translations.getText(context, 'error_prefix')} ${snapshot.error}"),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
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

          final allRides = snapshot.data!;
          final Distance distanceCalculator = const Distance();

          // Filter rides that pass near the user (within 3 km radius)
          final filteredRides = allRides.where((ride) {
            // 1. Check if potential route points exist
            if (ride.polylinePoints.isEmpty) {
              // Fallback: Check start location distance if no route data
              if (ride.startLat != 0 && ride.startLng != 0) {
                 return distanceCalculator.as(
                   LengthUnit.Meter,
                   pickup,
                   LatLng(ride.startLat, ride.startLng),
                 ) < 800;
              }
              return false;
            }

            // 2. Check if ANY point on the route is close to user
            // Optimization: radius reduced to 800m for better accuracy
            for (var p in ride.polylinePoints) {
              final double distInfo = distanceCalculator.as(LengthUnit.Meter, pickup, p);
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
                    Text(
                      Translations.getText(context, 'no_trips_nearby'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      Translations.getText(context, 'try_move_closer'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
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
                  final rideData = ride.toMap();

                  String formattedDate = Translations.getText(context, 'date_unknown');
                  try {
                    formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(ride.date);
                  } catch (e) {
                    formattedDate = Translations.getText(context, 'date_error');
                  }

                  String driverName = ride.driverName;
                  String destinationName = ride.destinationName;
                  // Get departure address with fallback to coordinates
                  String departureCity = ride.departureAddress ??
                      "${ride.startLat.toStringAsFixed(2)}, ${ride.startLng.toStringAsFixed(2)}";
                  String price = ride.price.toString();
                  String seats = ride.seats.toString();
                  String? phone;
                  DateTime rideDate = ride.date;
                  
                  List<LatLng> polylinePoints = ride.polylinePoints;

                  final bool isMyRide = currentUserUid == ride.driverId;
                  final String vehicleType = ride.vehicleType;
                  final String vehicleLabel = vehicleType == 'Moto'
                      ? Translations.getText(context, 'vehicle_moto')
                      : Translations.getText(context, 'vehicle_car');
                  final int availableSeats = ride.seats;

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
                                        imageUrl: ride.driverPhotoUrl,
                                        radius: 20,
                                        backgroundColor: scheme.primary.withOpacity(0.12),
                                        textColor: scheme.primary,
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
                                              Text(vehicleLabel, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: scheme.secondary.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: scheme.secondary.withOpacity(0.35)),
                                    ),
                                    child: Text(
                                      '$price MAD',
                                      style: TextStyle(color: scheme.secondary, fontWeight: FontWeight.bold, fontSize: 16),
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
                                        Text(
                                          Translations.getText(context, 'departure'),
                                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                        ),
                                        Text(departureCity, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Icon(Icons.arrow_forward, color: scheme.primary.withOpacity(0.6)),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          Translations.getText(context, 'arrival'),
                                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                        ),
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
                                        '$seats ${Translations.getText(context, 'seats')}',
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
                                              rideData: rideData,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.map, size: 18),
                                      label: Text(Translations.getText(context, 'map_view')),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: scheme.primary,
                                        side: BorderSide(color: scheme.primary),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  if (!isMyRide)
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: availableSeats > 0 
                                          ? () => _reserveRide(context, ride.id, rideData) 
                                          : null,
                                        icon: const Icon(Icons.bookmark_add, size: 18),
                                        label: Text(Translations.getText(context, 'book')),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: scheme.primary,
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor: scheme.surfaceVariant,
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
                                    child: Text(
                                      Translations.getText(context, 'full'),
                                      style: const TextStyle(
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
      _showSnackBar(context, Translations.getText(context, 'error_not_connected'), Colors.red);
      return;
    }

    // Confirmation Dialog
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Translations.getText(context, 'confirm_booking_title')),
        content: Text(Translations.getText(context, 'confirm_booking_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(Translations.getText(context, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(Translations.getText(context, 'confirm')),
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
    final scheme = Theme.of(context).colorScheme;
    final Color color = switch (result.status) {
      BookingCreateStatus.success => scheme.secondary,
      BookingCreateStatus.alreadyExists => scheme.tertiary,
      _ => scheme.error,
    };
    _showSnackBar(context, _bookingMessage(result), color);
  }
}
