import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/translations.dart';
import '../../screens/chat_screen.dart';
import '../../services/notification_service.dart';
import '../user_avatar.dart';
import '../../models/booking.dart';
import '../../models/ride.dart';
import '../../repositories/booking_repository.dart';
import '../../repositories/ride_repository.dart';

class PassengerBookingsList extends StatefulWidget {
  const PassengerBookingsList({super.key});

  @override
  State<PassengerBookingsList> createState() => _PassengerBookingsListState();
}

class _PassengerBookingsListState extends State<PassengerBookingsList> {
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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];
            final String status = booking.status.isEmpty ? 'pending' : booking.status;

            Color statusColor;
            String statusText;
            IconData statusIcon;

            switch (status) {
              case 'accepted':
                statusColor = scheme.secondary;
                statusText = Translations.getText(context, 'accepted');
                statusIcon = Icons.check_circle;
                break;
              case 'rejected':
                statusColor = scheme.error;
                statusText = Translations.getText(context, 'rejected');
                statusIcon = Icons.cancel;
                break;
              case 'pending':
              default:
                statusColor = scheme.tertiary;
                statusText = Translations.getText(context, 'pending');
                statusIcon = Icons.hourglass_empty;
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
                            ? UserAvatar(
                                userName: booking.driverName ?? '?',
                                imageUrl: booking.driverPhotoUrl,
                                radius: 22,
                                backgroundColor: Theme.of(context).cardColor,
                                textColor: scheme.primary,
                              )
                            : FutureBuilder<Ride?>(
                                future: RideRepository().fetchRide(booking.rideId),
                                builder: (context, rideSnap) {
                                  String? fallbackUrl;
                                  if (rideSnap.hasData && rideSnap.data != null) {
                                    fallbackUrl = rideSnap.data!.driverPhotoUrl;
                                  }
                                  return UserAvatar(
                                    userName: booking.driverName ?? '?',
                                    imageUrl: fallbackUrl,
                                    radius: 22,
                                    backgroundColor: Theme.of(context).cardColor,
                                    textColor: scheme.primary,
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
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

                        // Delete/Cancel Button for all statuses
                        TextButton.icon(
                          onPressed: () => _deleteBooking(booking.id, status == 'accepted'),
                          icon: Icon(
                            status == 'accepted' ? Icons.delete_forever : Icons.delete_outline,
                            size: 20,
                            color: scheme.error,
                          ),
                          label: Text(
                            status == 'pending' ? Translations.getText(context, 'cancel') : Translations.getText(context, 'delete'),
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
        );
      },
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





