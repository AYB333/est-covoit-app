import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../config/translations.dart';
import '../../screens/chat_screen.dart';
import '../../screens/public_profile_screen.dart';
import '../../screens/profile_screen.dart';
import 'package:est_covoit/screens/ride_details_screen.dart';
import '../../services/notification_service.dart';
import '../user_avatar.dart';
import '../../models/ride.dart';
import '../../models/booking.dart';
import '../../repositories/booking_repository.dart';
import '../../repositories/ride_repository.dart';

class DriverRidesList extends StatefulWidget {
  const DriverRidesList({super.key});

  @override
  State<DriverRidesList> createState() => _DriverRidesListState();
}

class _DriverRidesListState extends State<DriverRidesList> {
  DateTime? _filterDate;
  double? _filterMaxPrice;
  int _filterMinSeats = 0;

  bool get _hasFilters =>
      _filterDate != null || _filterMaxPrice != null || _filterMinSeats > 0;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_DriverFiltersResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return _DriverFiltersSheet(
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
    final scheme = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(child: Text(Translations.getText(context, 'not_connected')));
    }

    return StreamBuilder<List<Ride>>(
      stream: RideRepository().streamDriverRides(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_car_filled_outlined, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text(Translations.getText(context, 'no_trips'), style: const TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        final rides = snapshot.data!;
        final filteredRides = rides.where((ride) {
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
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Text(
                      Translations.getText(context, 'filters'),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_hasFilters)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _filterDate = null;
                            _filterMaxPrice = null;
                            _filterMinSeats = 0;
                          });
                        },
                        child: Text(
                          Translations.getText(context, 'clear_filters'),
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const Spacer(),
                    IconButton(
                      onPressed: _openFilters,
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    Translations.getText(context, 'filtered_empty'),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(
                    Translations.getText(context, 'filters'),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_hasFilters)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _filterDate = null;
                          _filterMaxPrice = null;
                          _filterMinSeats = 0;
                        });
                      },
                      child: Text(
                        Translations.getText(context, 'clear_filters'),
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    onPressed: _openFilters,
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredRides.length,
                itemBuilder: (context, index) {
                  final ride = filteredRides[index];
                  final date = ride.date;
                  final seats = ride.seats;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 15),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.all(15),
                          title: Text(
                            "${ride.departureAddress ?? Translations.getText(context, 'departure')} \u2192 EST",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(DateFormat('dd/MM HH:mm').format(date)),
                          leading: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ProfileScreen()),
                              );
                            },
                            child: UserAvatar(
                              userName: user.displayName ?? 'Moi',
                              imageUrl: user.photoURL,
                              radius: 20,
                              backgroundColor: scheme.primary.withOpacity(0.12),
                              textColor: scheme.primary,
                            ),
                          ),
                          trailing: Text(
                            "$seats ${Translations.getText(context, 'seats_available')}",
                            style: TextStyle(fontWeight: FontWeight.bold, color: seats > 0 ? scheme.secondary : scheme.error),
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Wrap(
                            alignment: WrapAlignment.spaceEvenly,
                            runSpacing: 6,
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                icon: Icon(Icons.edit, size: 18, color: scheme.primary),
                                label: Text(Translations.getText(context, 'edit'), style: TextStyle(color: scheme.primary)),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RideDetailsScreen(
                                        startLocation: LatLng(
                                          ride.startLat == 0 ? 30.4000 : ride.startLat,
                                          ride.startLng == 0 ? -9.6000 : ride.startLng,
                                        ),
                                        rideId: ride.id,
                                        rideData: ride.toMap(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              TextButton.icon(
                                icon: Icon(Icons.delete_outline, size: 18, color: scheme.error),
                                label: Text(Translations.getText(context, 'delete'), style: TextStyle(color: scheme.error)),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                ),
                                onPressed: () => _deleteRide(ride.id),
                              ),
                              StreamBuilder<List<Booking>>(
                                stream: BookingRepository().streamPendingBookings(ride.id),
                                builder: (context, snap) {
                                  int count = 0;
                                  if (snap.hasData) {
                                    count = snap.data!.length;
                                  }

                                  return TextButton.icon(
                                    icon: count > 0
                                        ? Badge(
                                            label: Text('$count'),
                                            backgroundColor: scheme.error,
                                            child: const Icon(Icons.people_alt_outlined, size: 18),
                                          )
                                        : const Icon(Icons.people_alt_outlined, size: 18),
                                    label: Text(
                                      Translations.getText(context, 'requests'),
                                      style: TextStyle(
                                        fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
                                        color: count > 0 ? scheme.primary : null,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    ),
                                    onPressed: () => _showRequestsModal(context, ride.id),
                                  );
                                },
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _deleteRide(String rideId) async {
    final scheme = Theme.of(context).colorScheme;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Translations.getText(context, 'delete')),
        content: Text(Translations.getText(context, 'delete_ride_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(Translations.getText(context, 'cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(Translations.getText(context, 'delete'), style: TextStyle(color: scheme.error)),
          )
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final bookingRepo = BookingRepository();
      final rideRepo = RideRepository();

      // Get all bookings for this ride
      final bookings = await bookingRepo.fetchBookingsForRide(rideId);
      for (var booking in bookings) {
        // Notify Passenger if booking was pending or accepted
        if (booking.status == 'pending' || booking.status == 'accepted') {
          NotificationService.sendNotification(
            receiverId: booking.passengerId,
            title: Translations.getText(context, 'ride_canceled_title'),
            body: "${Translations.getText(context, 'ride_canceled_body')} ${booking.departureAddress ?? ''}".trim(),
            type: "ride_cancel",
          );
        }
      }

      await rideRepo.deleteRideAndBookings(rideId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Translations.getText(context, 'ride_deleted'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${Translations.getText(context, 'error_prefix')} $e")),
        );
      }
    }
  }

  // --- LOGIC: Driver Requests Modal ---
  void _showRequestsModal(BuildContext context, String rideId) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Translations.getText(context, 'booking_requests'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<List<Booking>>(
                  stream: BookingRepository().streamRideBookings(rideId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(child: Text(Translations.getText(context, 'no_requests')));
                    }

                    // Client-side Sort: Pending first, then Accepted, then Rejected
                    final requests = snapshot.data!;
                    requests.sort((a, b) {
                      final sa = a.status.isEmpty ? 'pending' : a.status;
                      final sb = b.status.isEmpty ? 'pending' : b.status;

                      // Custom order: pending < accepted < rejected
                      int order(String s) {
                        if (s == 'pending') return 0;
                        if (s == 'accepted') return 1;
                        return 2;
                      }
                      return order(sa).compareTo(order(sb));
                    });

                    return ListView.builder(
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final req = requests[index];
                        final status = req.status.isEmpty ? 'pending' : req.status;
                        final passengerName = req.passengerName;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PublicProfileScreen(
                                          userId: req.passengerId,
                                          userName: passengerName,
                                          photoUrl: req.passengerPhotoUrl,
                                        ),
                                      ),
                                    );
                                  },
                                  child: UserAvatar(
                                    userName: passengerName,
                                    imageUrl: req.passengerPhotoUrl,
                                    radius: 20,
                                    backgroundColor: Colors.purple[50],
                                    textColor: Colors.purple[800],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(passengerName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text(
                                        status == 'pending'
                                            ? Translations.getText(context, 'pending')
                                            : status == 'accepted'
                                                ? Translations.getText(context, 'accepted')
                                                : Translations.getText(context, 'rejected'),
                                        style: TextStyle(
                                          color: status == 'pending'
                                              ? scheme.tertiary
                                              : status == 'accepted'
                                                  ? scheme.secondary
                                                  : scheme.error,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (status == 'pending') ...[
                                  IconButton(
                                    icon: Icon(Icons.check_circle, color: scheme.secondary, size: 30),
                                    onPressed: () => _handleBooking(req.id, rideId, true, req.passengerId),
                                    tooltip: Translations.getText(context, 'accept'),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.cancel, color: scheme.error, size: 30),
                                    onPressed: () => _handleBooking(req.id, rideId, false, req.passengerId),
                                    tooltip: Translations.getText(context, 'reject'),
                                  ),
                                ] else if (status == 'accepted') ...[
                                  IconButton(
                                    icon: Icon(Icons.chat_bubble, color: scheme.primary),
                                    tooltip: Translations.getText(context, 'discuss'),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ChatScreen(
                                            bookingId: req.id,
                                            otherUserName: passengerName,
                                            otherUserId: req.passengerId,
                                            otherUserPhotoUrl: req.passengerPhotoUrl,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  Icon(Icons.check_circle_outline, color: scheme.secondary),
                                ] else ...[
                                  const Icon(Icons.cancel_outlined, color: Colors.grey),
                                ]
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleBooking(String bookingId, String rideId, bool accept, String passengerId) async {
    if (accept) {
      try {
        await BookingRepository().acceptBookingWithSeatUpdate(
          bookingId: bookingId,
          rideId: rideId,
        );

        // Notify Passenger
        NotificationService.sendNotification(
          receiverId: passengerId,
          title: Translations.getText(context, 'booking_accepted_title'),
          body: Translations.getText(context, 'booking_accepted_body'),
          type: "booking_status",
        );

        if (mounted) Navigator.pop(context); // Close modal to refresh seats
      } catch (e) {
        String message = "${Translations.getText(context, 'error_prefix')} $e";
        if (e is StateError) {
          switch (e.message) {
            case 'no-seats':
              message = Translations.getText(context, 'error_no_seats');
              break;
            case 'booking-not-pending':
              message = Translations.getText(context, 'error_request_processed');
              break;
            case 'ride-missing':
              message = Translations.getText(context, 'error_ride_not_found');
              break;
            default:
              message = Translations.getText(context, 'error_processing');
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        }
      }
    } else {
      try {
        final bookingRepo = BookingRepository();
        final booking = await bookingRepo.fetchBooking(bookingId);
        if (booking == null) return;

        final status = booking.status.isEmpty ? 'pending' : booking.status;
        if (status != 'pending') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(Translations.getText(context, 'error_request_processed'))),
            );
          }
          return;
        }

        await bookingRepo.rejectBooking(bookingId);

        // Notify Passenger
        NotificationService.sendNotification(
          receiverId: passengerId,
          title: Translations.getText(context, 'booking_rejected_title'),
          body: Translations.getText(context, 'booking_rejected_body'),
          type: "booking_status",
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("${Translations.getText(context, 'error_prefix')} $e")),
          );
        }
      }
    }
  }
}

class _DriverFiltersResult {
  final DateTime? date;
  final double? maxPrice;
  final int minSeats;

  const _DriverFiltersResult({
    required this.date,
    required this.maxPrice,
    required this.minSeats,
  });
}

class _DriverFiltersSheet extends StatefulWidget {
  final DateTime? initialDate;
  final double? initialMaxPrice;
  final int initialMinSeats;

  const _DriverFiltersSheet({
    required this.initialDate,
    required this.initialMaxPrice,
    required this.initialMinSeats,
  });

  @override
  State<_DriverFiltersSheet> createState() => _DriverFiltersSheetState();
}

class _DriverFiltersSheetState extends State<_DriverFiltersSheet> {
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
      _DriverFiltersResult(
        date: _selectedDate,
        maxPrice: parsed,
        minSeats: _minSeats,
      ),
    );
  }

  void _clear() {
    Navigator.pop(
      context,
      const _DriverFiltersResult(
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




