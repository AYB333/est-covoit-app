import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/booking_service.dart';
import '../config/translations.dart';

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

  Future<void> _reserveRide() async {
    if (widget.rideId == null || widget.rideData == null) {
      _showSnackBar(Translations.getText(context, 'error_trip_missing_data'), Colors.red);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar(Translations.getText(context, 'error_not_connected'), Colors.red);
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
      rideId: widget.rideId!,
      rideData: widget.rideData!,
    );

    if (!context.mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final Color color = switch (result.status) {
      BookingCreateStatus.success => scheme.secondary,
      BookingCreateStatus.alreadyExists => scheme.tertiary,
      _ => scheme.error,
    };
    _showSnackBar(_bookingMessage(result), color);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
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
        title: Text("${Translations.getText(context, 'ride_of')} ${widget.driverName}"),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: startPoint ?? _estAgadirLocation,
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.est_covoit',
              ),
              if (widget.polylinePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: widget.polylinePoints,
                      color: scheme.primary,
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
                      child: Icon(Icons.location_on, color: scheme.secondary, size: 40),
                    ),
                  Marker(
                    point: _estAgadirLocation,
                    width: 80,
                    height: 80,
                    child: Icon(Icons.school, color: scheme.tertiary, size: 40),
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
                      "${Translations.getText(context, 'driver')}: ${widget.driverName}",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: scheme.primary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${Translations.getText(context, 'price')}: ${widget.price} MAD",
                          style: const TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                        Text(
                          "${Translations.getText(context, 'date')}: ${DateFormat('dd/MM HH:mm').format(widget.date)}",
                          style: const TextStyle(fontSize: 16, color: Colors.black87),
                        ),
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
                            seats > 0
                                ? Translations.getText(context, 'book_this_trip')
                                : Translations.getText(context, 'full'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: seats > 0 ? scheme.primary : scheme.surfaceVariant,
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
