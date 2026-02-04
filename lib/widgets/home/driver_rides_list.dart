import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../config/translations.dart';
import '../../screens/chat_screen.dart';
import '../../screens/ride_details_screen.dart';
import '../../services/notification_service.dart';
import '../user_avatar.dart';

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

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rides')
          .where('driverId', isEqualTo: user.uid)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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

        final rides = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rides.length,
          itemBuilder: (context, index) {
            final rideDoc = rides[index];
            final data = rideDoc.data() as Map<String, dynamic>;
            final date = (data['date'] as Timestamp).toDate();
            final seats = (data['seats'] as num?)?.toInt() ?? 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 15),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.all(15),
                    title: Text(
                      "${data['departureAddress'] ?? Translations.getText(context, 'departure')} \u2192 EST",
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
                                    data['startLat'] ?? 30.4000,
                                    data['startLng'] ?? -9.6000,
                                  ),
                                  rideId: rideDoc.id,
                                  rideData: data,
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
                          onPressed: () => _deleteRide(rideDoc.id),
                        ),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('bookings')
                              .where('rideId', isEqualTo: rideDoc.id)
                              .where('status', isEqualTo: 'pending')
                              .snapshots(),
                          builder: (context, snap) {
                            int count = 0;
                            if (snap.hasData) {
                              count = snap.data!.docs.length;
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
                              onPressed: () => _showRequestsModal(context, rideDoc.id),
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
      final batch = FirebaseFirestore.instance.batch();
      final rideRef = FirebaseFirestore.instance.collection('rides').doc(rideId);

      // Get all bookings for this ride
      final bookingsQuery =
          await FirebaseFirestore.instance.collection('bookings').where('rideId', isEqualTo: rideId).get();

      for (var doc in bookingsQuery.docs) {
        final data = doc.data();
        // Notify Passenger if booking was pending or accepted
        if (data['status'] == 'pending' || data['status'] == 'accepted') {
          NotificationService.sendNotification(
            receiverId: data['passengerId'],
            title: "Trajet Annulé",
            body: "Le conducteur a annulé le trajet ${data['departureAddress'] ?? ''}.",
            type: "ride_cancel",
          );
        }
        // Delete booking
        batch.delete(doc.reference);
      }

      // Delete ride
      batch.delete(rideRef);

      await batch.commit();

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
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('bookings').where('rideId', isEqualTo: rideId).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text("Aucune demande."));
                    }

                    // Client-side Sort: Pending first, then Accepted, then Rejected
                    final requests = snapshot.data!.docs;
                    requests.sort((a, b) {
                      final da = a.data() as Map<String, dynamic>;
                      final db = b.data() as Map<String, dynamic>;
                      final sa = da['status'] ?? 'pending';
                      final sb = db['status'] ?? 'pending';

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
                        final rData = req.data() as Map<String, dynamic>;
                        final status = rData['status'] ?? 'pending';
                        final passengerName = rData['passengerName'] ?? 'Passager';

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
                                  imageUrl: rData['passengerPhotoUrl'],
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
                                    onPressed: () => _handleBooking(req.id, rideId, true, rData['passengerId']),
                                    tooltip: "Accepter",
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.cancel, color: scheme.error, size: 30),
                                    onPressed: () => _handleBooking(req.id, rideId, false, rData['passengerId']),
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
                                            otherUserId: rData['passengerId'],
                                            otherUserPhotoUrl: rData['passengerPhotoUrl'],
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
        final rideRef = FirebaseFirestore.instance.collection('rides').doc(rideId);
        final bookingRef = FirebaseFirestore.instance.collection('bookings').doc(bookingId);

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final rideSnap = await transaction.get(rideRef);
          if (!rideSnap.exists) throw StateError('ride-missing');

          final bookingSnap = await transaction.get(bookingRef);
          if (!bookingSnap.exists) throw StateError('booking-missing');

          final bookingData = bookingSnap.data() as Map<String, dynamic>;
          final status = bookingData['status'] ?? 'pending';
          if (status != 'pending') throw StateError('booking-not-pending');

          final seats = (rideSnap.data()?['seats'] as num?)?.toInt() ?? 0;
          if (seats <= 0) throw StateError('no-seats');

          transaction.update(bookingRef, {
            'status': 'accepted',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          transaction.update(rideRef, {'seats': seats - 1});
        });

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
        final bookingRef = FirebaseFirestore.instance.collection('bookings').doc(bookingId);
        final bookingSnap = await bookingRef.get();
        if (!bookingSnap.exists) return;

        final bookingData = bookingSnap.data() as Map<String, dynamic>;
        final status = bookingData['status'] ?? 'pending';
        if (status != 'pending') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Demande deja traitee.")));
          }
          return;
        }

        await bookingRef.update({
          'status': 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        });

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
