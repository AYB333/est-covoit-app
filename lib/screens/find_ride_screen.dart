import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:est_covoit/screens/ride_map_viewer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/user_avatar.dart';
import '../config/translations.dart';
import 'public_profile_screen.dart';
import '../services/booking_service.dart';
import '../models/ride.dart';
import '../models/user_profile.dart';
import '../repositories/ride_repository.dart';
import '../repositories/safety_repository.dart';
import '../repositories/user_repository.dart';


// --- SCREEN: FIND RIDE ---
class FindRideScreen extends StatefulWidget {
  final LatLng? userPickupLocation;

  const FindRideScreen({super.key, this.userPickupLocation});

  @override
  State<FindRideScreen> createState() => _FindRideScreenState();
}

class _FindRideScreenState extends State<FindRideScreen> {
  // --- FILTERS STATE ---
  DateTime? _filterDate;
  double? _filterMaxPrice;
  int _filterMinSeats = 0;

  bool get _hasFilters =>
      _filterDate != null || _filterMaxPrice != null || _filterMinSeats > 0;

  // --- SNACKBAR ---
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

  // --- BOOKING RESULT MESSAGE ---
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
        final double avg = profile?.ratingAvg ?? 0;
        final int count = profile?.ratingCount ?? 0;
        if (count <= 0) {
          return Text(
            Translations.getText(context, 'no_reviews'),
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          );
        }

        return Row(
          children: [
            Icon(Icons.star_rounded, size: 14, color: scheme.tertiary),
            const SizedBox(width: 3),
            Text(
              '${avg.toStringAsFixed(1)} ($count)',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
            ),
          ],
        );
      },
    );
  }

  // --- DISTANCE: pickup -> ride (polyline/start) ---
  double _distanceToRideMeters({
    required Ride ride,
    required LatLng pickup,
    required Distance calculator,
  }) {
    if (ride.polylinePoints.isNotEmpty) {
      double minDist = double.infinity;
      for (final point in ride.polylinePoints) {
        final dist = calculator.as(LengthUnit.Meter, pickup, point);
        if (dist < minDist) minDist = dist;
      }
      return minDist;
    }

    if (ride.startLat != 0 || ride.startLng != 0) {
      return calculator.as(
        LengthUnit.Meter,
        pickup,
        LatLng(ride.startLat, ride.startLng),
      );
    }

    return 100000;
  }

  // --- SMART SCORE (distance/price/time/seats) ---
  double _smartScore({
    required Ride ride,
    required double distanceMeters,
    required double maxPrice,
    required DateTime now,
  }) {
    final distanceScore = (1 - (distanceMeters / 1500)).clamp(0.0, 1.0);
    final priceScore = (1 - (ride.price / maxPrice)).clamp(0.0, 1.0);
    final seatScore = (ride.seats / 4).clamp(0.0, 1.0);
    final hoursAhead = ride.date.difference(now).inMinutes / 60.0;
    final timeScore = (1 - (hoursAhead / 24)).clamp(0.0, 1.0);

    return (distanceScore * 0.45) +
        (priceScore * 0.25) +
        (timeScore * 0.20) +
        (seatScore * 0.10);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // --- OPEN FILTERS SHEET ---
  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_FindRideFilterResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return _FindRideFiltersSheet(
          initialDate: _filterDate,
          initialMaxPrice: _filterMaxPrice,
          initialMinSeats: _filterMinSeats,
        );
      },
    );
    if (!mounted || result == null) return;
    setState(() {
      _filterDate = result.date;
      _filterMaxPrice = result.maxPrice;
      _filterMinSeats = result.minSeats;
    });
  }

  @override
  Widget build(BuildContext context) {
    final LatLng? pickup = widget.userPickupLocation;
    final scheme = Theme.of(context).colorScheme;
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    // --- GUARD: PICKUP REQUIRED ---
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

    final Stream<Set<String>> blockedUsersStream = currentUserUid == null
        ? Stream.value(<String>{})
        : SafetyRepository().streamBlockedUserIds(currentUserUid);

    // --- MAIN UI ---
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
        actions: [
          IconButton(
            onPressed: _openFilters,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.tune_rounded),
                if (_hasFilters)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      // --- STREAM: BLOCKED USERS + RIDES ---
      body: StreamBuilder<Set<String>>(
        stream: blockedUsersStream,
        builder: (context, blockedSnap) {
          final blockedUsers = blockedSnap.data ?? <String>{};
          return StreamBuilder<List<Ride>>(
            // Filter rides where the 'date' field is greater than or equal to the current date/time
            stream: RideRepository().streamAvailableRidesFrom(
              DateTime.now().subtract(const Duration(days: 1)),
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting || blockedSnap.connectionState == ConnectionState.waiting) {
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

              // Filter rides that pass near the user (within 800m radius) and ignore blocked drivers.
              final nearbyRides = allRides.where((ride) {
                if (blockedUsers.contains(ride.driverId)) return false;

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

              if (nearbyRides.isEmpty) {
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

              final filteredRides = nearbyRides.where((ride) {
                if (_filterDate != null && !_isSameDay(ride.date, _filterDate!)) {
                  return false;
                }
                if (_filterMaxPrice != null && ride.price > _filterMaxPrice!) {
                  return false;
                }
                if (_filterMinSeats > 0 && ride.seats < _filterMinSeats) {
                  return false;
                }
                return true;
              }).toList();

              if (filteredRides.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      Translations.getText(context, 'filtered_empty'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                );
              }

              final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
              final maxPrice = filteredRides.fold<double>(
                1.0,
                (max, ride) => ride.price > max ? ride.price : max,
              );
              final now = DateTime.now();
              final scoredRides = filteredRides
                  .map((ride) {
                    final distanceM = _distanceToRideMeters(
                      ride: ride,
                      pickup: pickup,
                      calculator: distanceCalculator,
                    );
                    final score = _smartScore(
                      ride: ride,
                      distanceMeters: distanceM,
                      maxPrice: maxPrice,
                      now: now,
                    );
                    return (ride: ride, score: score);
                  })
                  .toList()
                ..sort((a, b) => b.score.compareTo(a.score));

              // --- LIST: MATCHED RIDES ---
              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: scoredRides.length,
                itemBuilder: (context, index) {
                  final item = scoredRides[index];
                  final ride = item.ride;
                  final matchPercent = (item.score * 100).round();
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
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => PublicProfileScreen(
                                                userId: ride.driverId,
                                                userName: driverName,
                                                photoUrl: ride.driverPhotoUrl,
                                              ),
                                            ),
                                          );
                                        },
                                        child: UserAvatar(
                                          userName: driverName,
                                          imageUrl: ride.driverPhotoUrl,
                                          radius: 20,
                                          backgroundColor: scheme.primary.withValues(alpha: 0.12),
                                          textColor: scheme.primary,
                                        ),
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
                                          const SizedBox(height: 2),
                                          _buildDriverRating(ride.driverId),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: scheme.secondary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: scheme.secondary.withValues(alpha: 0.35)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '$price MAD',
                                          style: TextStyle(color: scheme.secondary, fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Text(
                                          '$matchPercent% ${Translations.getText(context, 'match_label')}',
                                          style: TextStyle(
                                            color: scheme.onSurfaceVariant,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
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
                                    child: Icon(Icons.arrow_forward, color: scheme.primary.withValues(alpha: 0.6)),
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
                                          disabledBackgroundColor: scheme.surfaceContainerHighest,
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
                                color: Colors.white.withValues(alpha: 0.85),
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
          );
        },
      ),
    );
  }

  // --- RESERVE RIDE FLOW ---
  Future<void> _reserveRide(BuildContext context, String rideId, Map<String, dynamic> rideData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar(context, Translations.getText(context, 'error_not_connected'), Colors.red);
      return;
    }

    final driverId = rideData['driverId']?.toString();
    if (driverId != null && driverId.isNotEmpty) {
      final blocked = await SafetyRepository().isBlocked(
        blockerId: user.uid,
        blockedUserId: driverId,
      );
      if (!context.mounted) return;
      if (blocked) {
        _showSnackBar(context, Translations.getText(context, 'blocked_action_unavailable'), Colors.red);
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

    if (!context.mounted) return;
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

// --- FILTER RESULT MODEL ---
class _FindRideFilterResult {
  final DateTime? date;
  final double? maxPrice;
  final int minSeats;

  const _FindRideFilterResult({
    required this.date,
    required this.maxPrice,
    required this.minSeats,
  });
}

// --- FILTERS SHEET (UI) ---
class _FindRideFiltersSheet extends StatefulWidget {
  final DateTime? initialDate;
  final double? initialMaxPrice;
  final int initialMinSeats;

  const _FindRideFiltersSheet({
    required this.initialDate,
    required this.initialMaxPrice,
    required this.initialMinSeats,
  });

  @override
  State<_FindRideFiltersSheet> createState() => _FindRideFiltersSheetState();
}

// --- FILTERS SHEET STATE ---
class _FindRideFiltersSheetState extends State<_FindRideFiltersSheet> {
  late final TextEditingController _maxPriceController;
  DateTime? _selectedDate;
  late int _minSeats;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _minSeats = widget.initialMinSeats;
    _maxPriceController = TextEditingController(
      text: widget.initialMaxPrice?.toStringAsFixed(1) ?? '',
    );
  }

  @override
  void dispose() {
    _maxPriceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _apply() {
    final raw = _maxPriceController.text.trim().replaceAll(',', '.');
    double? parsed;
    if (raw.isNotEmpty) {
      parsed = double.tryParse(raw);
      if (parsed == null || parsed < 0) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(Translations.getText(context, 'filter_invalid_price'))),
        );
        return;
      }
    }

    Navigator.pop(
      context,
      _FindRideFilterResult(
        date: _selectedDate,
        maxPrice: parsed,
        minSeats: _minSeats,
      ),
    );
  }

  void _clear() {
    Navigator.pop(
      context,
      const _FindRideFilterResult(
        date: null,
        maxPrice: null,
        minSeats: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Translations.getText(context, 'filters'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(Translations.getText(context, 'date')),
            subtitle: Text(
              _selectedDate == null
                  ? Translations.getText(context, 'filter_all_dates')
                  : DateFormat('dd/MM/yyyy').format(_selectedDate!),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.calendar_today_outlined),
              onPressed: _pickDate,
            ),
          ),
          TextField(
            controller: _maxPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: "${Translations.getText(context, 'price')} (MAD)",
              hintText: Translations.getText(context, 'filter_any_price'),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            initialValue: _minSeats,
            decoration: InputDecoration(
              labelText: Translations.getText(context, 'seats'),
            ),
            items: const [0, 1, 2, 3, 4]
                .map(
                  (value) => DropdownMenuItem<int>(
                    value: value,
                    child: Text(
                      value == 0
                          ? Translations.getText(context, 'filter_any_seats')
                          : '$value+',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _minSeats = value);
              }
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: _clear,
                child: Text(Translations.getText(context, 'clear_filters')),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _apply,
                child: Text(Translations.getText(context, 'filter_apply')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
