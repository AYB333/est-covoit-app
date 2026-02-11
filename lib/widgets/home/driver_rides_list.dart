import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../config/translations.dart';
import '../../screens/chat_screen.dart';
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
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("Non connecté"));

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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rides.length,
          itemBuilder: (context, index) {
            final ride = rides[index];
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
                    leading: UserAvatar(
                      userName: user.displayName ?? 'Moi',
                      imageUrl: user.photoURL,
                      radius: 20,
                      backgroundColor: scheme.primary.withOpacity(0.12),
                      textColor: scheme.primary,
                    ),
                    trailing: Text(
                      "$seats P. Disp.",
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
        );
      },
    );
  }

  void _deleteRide(String rideId) async {
    final scheme = Theme.of(context).colorScheme;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Supprimer"),
        content: const Text("Voulez-vous supprimer ce trajet ?\nCela annulera toutes les réservations associées."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Supprimer", style: TextStyle(color: scheme.error)),
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
            title: "Trajet Annulé",
            body: "Le conducteur a annulé le trajet ${booking.departureAddress ?? ''}.",
            type: "ride_cancel",
          );
        }
      }

      await rideRepo.deleteRideAndBookings(rideId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Trajet supprimé.")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
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
              const Text("Demandes de réservation", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: StreamBuilder<List<Booking>>(
                  stream: BookingRepository().streamRideBookings(rideId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text("Aucune demande."));
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
                                UserAvatar(
                                  userName: passengerName,
                                  imageUrl: req.passengerPhotoUrl,
                                  radius: 20,
                                  backgroundColor: Colors.purple[50],
                                  textColor: Colors.purple[800],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(passengerName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text(
                                        status == 'pending' ? 'En attente' : status == 'accepted' ? 'Accepté' : 'Refusé',
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
                                    tooltip: "Accepter",
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.cancel, color: scheme.error, size: 30),
                                    onPressed: () => _handleBooking(req.id, rideId, false, req.passengerId),
                                    tooltip: "Refuser",
                                  ),
                                ] else if (status == 'accepted') ...[
                                  IconButton(
                                    icon: Icon(Icons.chat_bubble, color: scheme.primary),
                                    tooltip: "Discuter",
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
          title: "Reservation acceptee !",
          body: "Le conducteur a accepte votre demande.",
          type: "booking_status",
        );

        if (mounted) Navigator.pop(context); // Close modal to refresh seats
      } catch (e) {
        String message = "Erreur: $e";
        if (e is StateError) {
          switch (e.message) {
            case 'no-seats':
              message = "Plus de places disponibles !";
              break;
            case 'booking-not-pending':
              message = "Demande deja traitee.";
              break;
            case 'ride-missing':
              message = "Trajet introuvable.";
              break;
            default:
              message = "Erreur traitement.";
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
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Demande deja traitee.")));
          }
          return;
        }

        await bookingRepo.rejectBooking(bookingId);

        // Notify Passenger
        NotificationService.sendNotification(
          receiverId: passengerId,
          title: "Reservation refusee",
          body: "Le conducteur a refuse votre demande.",
          type: "booking_status",
        );
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
      }
    }
  }
}


