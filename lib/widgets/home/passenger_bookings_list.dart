import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/translations.dart';
import '../../screens/chat_screen.dart';
import '../../screens/public_profile_screen.dart';
import '../../screens/review_screen.dart';
import '../../services/notification_service.dart';
import '../user_avatar.dart';
import '../../models/booking.dart';
import '../../models/ride.dart';
import '../../repositories/booking_repository.dart';
import '../../repositories/review_repository.dart';
import '../../repositories/ride_repository.dart';

class PassengerBookingsList extends StatefulWidget {
  const PassengerBookingsList({super.key});

  @override
  State<PassengerBookingsList> createState() => _PassengerBookingsListState();
}

class _PassengerBookingsListState extends State<PassengerBookingsList> {
  final Set<String> _ratedBookingIds = <String>{};
  DateTime? _filterDate;
  double? _filterMaxPrice;
  String _filterStatus = 'all';

  bool get _hasFilters =>
      _filterDate != null || _filterMaxPrice != null || _filterStatus != 'all';

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_PassengerFiltersResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return _PassengerFiltersSheet(
          initialDate: _filterDate,
          initialMaxPrice: _filterMaxPrice,
          initialStatus: _filterStatus,
        );
      },
    );
    if (!mounted || result == null) return;
    setState(() {
      _filterDate = result.date;
      _filterMaxPrice = result.maxPrice;
      _filterStatus = result.status;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(child: Text(Translations.getText(context, 'not_connected')));
    }

    return StreamBuilder<List<Booking>>(
      stream: BookingRepository().streamPassengerBookings(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "${Translations.getText(context, 'error_prefix')} ${snapshot.error}",
                style: TextStyle(color: scheme.error),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_border, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text(Translations.getText(context, 'no_bookings'), style: const TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        // Client-side sorting to avoid Index issues
        final bookings = snapshot.data!;
        bookings.sort((a, b) {
          final tA = a.timestamp;
          final tB = b.timestamp;
          if (tA == null) return -1; // Show new items first (optimistic UI)
          if (tB == null) return 1;
          return tB.compareTo(tA); // Descending
        });

        final filteredBookings = bookings.where((booking) {
          final String status = booking.status.isEmpty ? 'pending' : booking.status;
          if (_filterStatus != 'all' && status != _filterStatus) {
            return false;
          }
          if (_filterDate != null) {
            if (booking.rideDate == null || !_isSameDay(booking.rideDate!, _filterDate!)) {
              return false;
            }
          }
          if (_filterMaxPrice != null) {
            final price = booking.ridePrice ?? 0;
            if (price > _filterMaxPrice!) {
              return false;
            }
          }
          return true;
        }).toList();

        if (filteredBookings.isEmpty) {
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
                            _filterStatus = 'all';
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
                          _filterStatus = 'all';
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
                itemCount: filteredBookings.length,
                itemBuilder: (context, index) {
                  final booking = filteredBookings[index];
            final String status = booking.status.isEmpty ? 'pending' : booking.status;

            Color statusColor;
            String statusText;

            switch (status) {
              case 'accepted':
                statusColor = scheme.secondary;
                statusText = Translations.getText(context, 'accepted');
                break;
              case 'rejected':
                statusColor = scheme.error;
                statusText = Translations.getText(context, 'rejected');
                break;
              case 'pending':
              default:
                statusColor = scheme.tertiary;
                statusText = Translations.getText(context, 'pending');
                break;
            }

            // Format Date
            String dateStr = "";
            if (booking.rideDate != null) {
              try {
                dateStr = DateFormat('dd/MM HH:mm').format(booking.rideDate!);
              } catch (_) {}
            }

            // Route
            String route = "${booking.departureAddress ?? Translations.getText(context, 'departure')} \u2192 ${booking.rideDestination.isEmpty ? 'EST' : booking.rideDestination}";
            if (route.length > 30) route = "${route.substring(0, 30)}...";

                  return Card(
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).highlightColor.withOpacity(0.1),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    ),
                    child: Row(
                      children: [
                        // Dynamic Driver Avatar with Fallback
                        booking.driverPhotoUrl != null && booking.driverPhotoUrl!.isNotEmpty
                            ? GestureDetector(
                                onTap: () => _openPublicProfile(
                                  userId: booking.driverId,
                                  userName: booking.driverName ?? '?',
                                  photoUrl: booking.driverPhotoUrl,
                                ),
                                child: UserAvatar(
                                  userName: booking.driverName ?? '?',
                                  imageUrl: booking.driverPhotoUrl,
                                  radius: 22,
                                  backgroundColor: Theme.of(context).cardColor,
                                  textColor: scheme.primary,
                                ),
                              )
                            : FutureBuilder<Ride?>(
                                future: RideRepository().fetchRide(booking.rideId),
                                builder: (context, rideSnap) {
                                  String? fallbackUrl;
                                  if (rideSnap.hasData && rideSnap.data != null) {
                                    fallbackUrl = rideSnap.data!.driverPhotoUrl;
                                  }
                                  return GestureDetector(
                                    onTap: () => _openPublicProfile(
                                      userId: booking.driverId,
                                      userName: booking.driverName ?? '?',
                                      photoUrl: fallbackUrl,
                                    ),
                                    child: UserAvatar(
                                      userName: booking.driverName ?? '?',
                                      imageUrl: fallbackUrl,
                                      radius: 22,
                                      backgroundColor: Theme.of(context).cardColor,
                                      textColor: scheme.primary,
                                    ),
                                  );
                                },
                              ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                route,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${Translations.getText(context, 'driver')}: ${booking.driverName ?? Translations.getText(context, 'unknown')}",
                                style: TextStyle(color: Colors.grey[700], fontSize: 13),
                              ),
                              if (dateStr.isNotEmpty)
                                Text(
                                  dateStr,
                                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                            "${booking.ridePrice ?? '?'} MAD",
                              style: TextStyle(fontWeight: FontWeight.bold, color: scheme.secondary, fontSize: 16),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: statusColor.withOpacity(0.5)),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),

                  // Actions Section
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (status == 'accepted')
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    bookingId: booking.id,
                                    otherUserName: booking.driverName ?? Translations.getText(context, 'driver'),
                                    otherUserId: booking.driverId,
                                    otherUserPhotoUrl: booking.driverPhotoUrl,
                                  ),
                                ),
                              );
                            },
                            icon: Icon(Icons.chat_bubble_outline, size: 20, color: scheme.primary),
                            label: Text(
                              Translations.getText(context, 'discuss'),
                              style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                        if (status == 'accepted')
                          FutureBuilder<bool>(
                            future: ReviewRepository()
                                .fetchReviewForBooking(
                                  bookingId: booking.id,
                                  reviewerId: user.uid,
                                )
                                .then((review) => review != null),
                            builder: (context, snap) {
                              final bool rated =
                                  _ratedBookingIds.contains(booking.id) || (snap.data ?? false);
                              return TextButton.icon(
                                onPressed: rated ? null : () => _showReviewDialog(booking),
                                icon: Icon(
                                  rated ? Icons.star : Icons.star_border_rounded,
                                  size: 20,
                                  color: rated ? scheme.tertiary : scheme.primary,
                                ),
                                label: Text(
                                  rated
                                      ? Translations.getText(context, 'rated')
                                      : Translations.getText(context, 'rate'),
                                  style: TextStyle(color: rated ? scheme.tertiary : scheme.primary),
                                ),
                              );
                            },
                          ),
                        TextButton.icon(
                          onPressed: () => _deleteBooking(booking.id, status == 'accepted'),
                          icon: Icon(
                            status == 'accepted' ? Icons.delete_forever : Icons.delete_outline,
                            size: 20,
                            color: scheme.error,
                          ),
                          label: Text(
                            status == 'pending'
                                ? Translations.getText(context, 'cancel')
                                : Translations.getText(context, 'delete'),
                            style: TextStyle(color: scheme.error),
                          ),
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

  void _openPublicProfile({
    required String userId,
    required String userName,
    String? photoUrl,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(
          userId: userId,
          userName: userName,
          photoUrl: photoUrl,
        ),
      ),
    );
  }

  Future<void> _showReviewDialog(Booking booking) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;

    final String? result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          booking: booking,
          reviewerId: user.uid,
        ),
      ),
    );

    if (!mounted || result == null) return;

    if (result == 'submitted' || result == 'exists') {
      setState(() {
        _ratedBookingIds.add(booking.id);
      });
    }

    String message;
    if (result == 'submitted') {
      message = Translations.getText(context, 'review_submitted');
    } else if (result == 'exists') {
      message = Translations.getText(context, 'review_exists');
    } else {
      message = Translations.getText(context, 'review_error');
    }

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _deleteBooking(String bookingId, bool isAccepted) async {
    final scheme = Theme.of(context).colorScheme;
    // Confirmation Dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAccepted ? Translations.getText(context, 'delete') : Translations.getText(context, 'cancel')),
        content: Text(isAccepted
            ? Translations.getText(context, 'cancel_booking_confirm')
            : Translations.getText(context, 'cancel_request_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(Translations.getText(context, 'back_btn')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, true);
            },
            child: Text(
              Translations.getText(context, 'confirm'),
              style: TextStyle(color: scheme.error, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final bookingRepo = BookingRepository();
      final booking = await bookingRepo.fetchBooking(bookingId);
      if (booking == null) return;

      final String rideId = booking.rideId;
      final String driverId = booking.driverId;
      final String passengerName = booking.passengerName.isEmpty
          ? Translations.getText(context, 'passenger')
          : booking.passengerName;
      final String status = booking.status.isEmpty ? 'pending' : booking.status;
      final bool wasAccepted = status == 'accepted';

      if (wasAccepted) {
        await bookingRepo.deleteBookingAndRestoreSeat(
          bookingId: bookingId,
          rideId: rideId,
        );

        // Notify Driver
        NotificationService.sendNotification(
          receiverId: driverId,
          title: Translations.getText(context, 'booking_cancel_title'),
          body: "$passengerName ${Translations.getText(context, 'booking_cancel_body')}",
          type: "booking_cancel",
        );
      } else {
        await bookingRepo.deleteBooking(bookingId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Translations.getText(context, 'booking_deleted'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${Translations.getText(context, 'error_prefix')} $e")),
        );
      }
    }
  }
}


class _PassengerFiltersResult {
  final DateTime? date;
  final double? maxPrice;
  final String status;

  const _PassengerFiltersResult({
    required this.date,
    required this.maxPrice,
    required this.status,
  });
}

class _PassengerFiltersSheet extends StatefulWidget {
  final DateTime? initialDate;
  final double? initialMaxPrice;
  final String initialStatus;

  const _PassengerFiltersSheet({
    required this.initialDate,
    required this.initialMaxPrice,
    required this.initialStatus,
  });

  @override
  State<_PassengerFiltersSheet> createState() => _PassengerFiltersSheetState();
}

class _PassengerFiltersSheetState extends State<_PassengerFiltersSheet> {
  late final TextEditingController _maxPriceController;
  DateTime? _selectedDate;
  late String _status;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _status = widget.initialStatus;
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
      _PassengerFiltersResult(
        date: _selectedDate,
        maxPrice: parsed,
        status: _status,
      ),
    );
  }

  void _clear() {
    Navigator.pop(
      context,
      const _PassengerFiltersResult(
        date: null,
        maxPrice: null,
        status: 'all',
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
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: InputDecoration(
              labelText: Translations.getText(context, 'status_label'),
            ),
            items: [
              DropdownMenuItem<String>(
                value: 'all',
                child: Text(Translations.getText(context, 'filter_all_status')),
              ),
              DropdownMenuItem<String>(
                value: 'pending',
                child: Text(Translations.getText(context, 'pending')),
              ),
              DropdownMenuItem<String>(
                value: 'accepted',
                child: Text(Translations.getText(context, 'accepted')),
              ),
              DropdownMenuItem<String>(
                value: 'rejected',
                child: Text(Translations.getText(context, 'rejected')),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _status = value);
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




