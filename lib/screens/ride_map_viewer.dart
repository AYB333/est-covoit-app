import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/booking_service.dart';
import '../config/translations.dart';
import '../models/user_profile.dart';
import '../repositories/safety_repository.dart';
import '../repositories/user_repository.dart';
import 'public_profile_screen.dart';

// --- SCREEN: MAP VIEW + BOOKING ---
class RideMapViewer extends StatefulWidget {
  final List<LatLng> polylinePoints;
  final String driverName;
  final String? phone;
  final String price;
  final DateTime date;
  
  // --- RESERVATION DATA ---
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
  // --- CONST: DESTINATION ---
  static const LatLng _estAgadirLocation = LatLng(30.4070, -9.5790);

  // --- SNACKBAR ---
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  // --- MESSAGE FROM BOOKING RESULT ---
  String _bookingMessage(BookingCreateResult result) {
    switch (result.status) {
      case BookingCreateStatus.success:
        return Translations.getText(context, 'booking_request_sent');
      case BookingCreateStatus.alreadyExists:
        return Translations.getText(context, 'booking_already_exists');
      case BookingCreateStatus.invalidData:
        return Translations.getText(context, 'booking_invalid_data');
      case BookingCreateStatus.error:
        return Translations.getText(context, 'booking_error_generic');
    }
  }

  // --- DRIVER RATING WIDGET ---
  Widget _buildDriverRating(String driverId) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<UserProfile?>(
      stream: UserRepository().streamProfile(driverId),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final avg = profile?.ratingAvg ?? 0;
        final count = profile?.ratingCount ?? 0;
        if (count <= 0) {
          return Text(
            Translations.getText(context, 'no_reviews'),
            style: TextStyle(color: scheme.onSurfaceVariant),
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: 18, color: scheme.tertiary),
            const SizedBox(width: 4),
            Text(
              '${avg.toStringAsFixed(1)} ($count)',
              style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
            ),
          ],
        );
      },
    );
  }

  // --- RESERVE RIDE FLOW ---
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

    final driverId = widget.rideData!['driverId']?.toString();
    if (driverId != null && driverId.isNotEmpty) {
      final blocked = await SafetyRepository().isBlocked(
        blockerId: user.uid,
        blockedUserId: driverId,
      );
      if (!mounted) return;
      if (blocked) {
        _showSnackBar(Translations.getText(context, 'blocked_action_unavailable'), Colors.red);
        return;
      }
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

    if (!mounted) return;
    if (confirm != true) return;

    final result = await BookingService.reserveRide(
      user: user,
      rideId: widget.rideId!,
      rideData: widget.rideData!,
    );

    if (!mounted) return;
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
    LatLng? startPoint;
    if (widget.polylinePoints.isNotEmpty) {
      startPoint = widget.polylinePoints.first;
    }

    // --- CHECK: IS MY RIDE? ---
    final user = FirebaseAuth.instance.currentUser;
    final bool isMyRide = (user != null && widget.rideData != null && user.uid == widget.rideData!['driverId']);
    final int seats = (widget.rideData != null && widget.rideData!['seats'] is num) 
        ? (widget.rideData!['seats'] as num).toInt() 
        : 0;

    // --- UI ---
    return Scaffold(
      appBar: AppBar(
        title: Text("${Translations.getText(context, 'ride_of')} ${widget.driverName}"),
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
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${Translations.getText(context, 'driver')}: ${widget.driverName}",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (widget.rideData != null && widget.rideData!['driverId'] != null)
                    _buildDriverRating(widget.rideData!['driverId'].toString()),
                  if (widget.rideData != null && widget.rideData!['driverId'] != null) ...[
                    const SizedBox(height: 10),
                    Center(
                      child: SizedBox(
                        width: 210,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PublicProfileScreen(
                                  userId: widget.rideData!['driverId'].toString(),
                                  userName: widget.driverName,
                                  photoUrl: widget.rideData!['driverPhotoUrl']?.toString(),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.person_outline, size: 18),
                          label: Text(Translations.getText(context, 'view_profile')),
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.center,
                            foregroundColor: scheme.primary,
                            textStyle: const TextStyle(fontWeight: FontWeight.w600),
                            side: BorderSide(color: scheme.primary.withValues(alpha: 0.55)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.payments_outlined, size: 16, color: scheme.secondary),
                          const SizedBox(width: 4),
                          Text(
                            "${Translations.getText(context, 'price')}: ${widget.price} MAD",
                            style: TextStyle(
                              fontSize: 16,
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 15, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd/MM HH:mm').format(widget.date),
                            style: TextStyle(
                              fontSize: 16,
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  if (!isMyRide && widget.rideData != null) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: seats > 0 ? _reserveRide : null,
                        icon: const Icon(Icons.bookmark_added, color: Colors.white),
                        label: Text(
                          seats > 0
                              ? Translations.getText(context, 'book_this_trip')
                              : Translations.getText(context, 'full'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: seats > 0 ? scheme.primary : scheme.surfaceContainerHighest,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
