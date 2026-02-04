import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/translations.dart';
import '../../screens/chat_screen.dart';
import '../../services/notification_service.dart';
import '../user_avatar.dart';

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
    if (user == null) return const Center(child: Text("Non connectÃ©"));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('bookings').where('passengerId', isEqualTo: user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("Erreur: ${snapshot.error}", style: TextStyle(color: scheme.error), textAlign: TextAlign.center),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
        final bookings = snapshot.data!.docs;
        bookings.sort((a, b) {
          final da = a.data() as Map<String, dynamic>;
          final db = b.data() as Map<String, dynamic>;
          final Timestamp? tA = da['timestamp'] as Timestamp?;
          final Timestamp? tB = db['timestamp'] as Timestamp?;
          if (tA == null) return -1; // Show new items first (optimistic UI)
          if (tB == null) return 1;
          return tB.compareTo(tA); // Descending
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final bookingDoc = bookings[index];
            final b = bookingDoc.data() as Map<String, dynamic>;
            final String status = b['status'] ?? 'pending';

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
            if (b['rideDate'] != null) {
              try {
                dateStr = DateFormat('dd/MM HH:mm').format((b['rideDate'] as Timestamp).toDate());
              } catch (_) {}
            }

            // Route
            String route = "${b['departureAddress'] ?? 'DÃ©part'} â†’ ${b['rideDestination'] ?? 'EST'}";
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
                        b['driverPhotoUrl'] != null && (b['driverPhotoUrl'] as String).isNotEmpty
                            ? UserAvatar(
                                userName: b['driverName'] ?? '?',
                                imageUrl: b['driverPhotoUrl'],
                                radius: 22,
                                backgroundColor: Theme.of(context).cardColor,
                                textColor: scheme.primary,
                              )
                            : FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance.collection('rides').doc(b['rideId']).get(),
                                builder: (context, rideSnap) {
                                  String? fallbackUrl;
                                  if (rideSnap.hasData && rideSnap.data!.exists) {
                                    fallbackUrl = (rideSnap.data!.data() as Map<String, dynamic>)['driverPhotoUrl'];
                                  }
                                  return UserAvatar(
                                    userName: b['driverName'] ?? '?',
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
                                "${Translations.getText(context, 'driver')}: ${b['driverName'] ?? Translations.getText(context, 'unknown')}",
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
                              "${b['ridePrice'] ?? '?'} MAD",
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
                                    bookingId: bookingDoc.id,
                                    otherUserName: b['driverName'] ?? 'Conducteur',
                                    otherUserId: b['driverId'],
                                    otherUserPhotoUrl: b['driverPhotoUrl'],
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
                          onPressed: () => _deleteBooking(bookingDoc.id, status == 'accepted'),
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
        title: Text(isAccepted ? "Supprimer" : "Annuler"),
        content: Text(isAccepted
            ? "Voulez-vous vraiment annuler cette reservation ?\nLe conducteur sera notifie."
            : "Voulez-vous annuler cette demande ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Retour")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, true);
            },
            child: Text("Confirmer", style: TextStyle(color: scheme.error, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final bookingRef = FirebaseFirestore.instance.collection('bookings').doc(bookingId);
      final doc = await bookingRef.get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      final String rideId = data['rideId'];
      final String driverId = data['driverId'];
      final String passengerName = data['passengerName'] ?? 'Un passager';
      final String status = data['status'] ?? 'pending';
      final bool wasAccepted = status == 'accepted';

      if (wasAccepted) {
        final rideRef = FirebaseFirestore.instance.collection('rides').doc(rideId);
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final rideSnap = await transaction.get(rideRef);
          if (rideSnap.exists) {
            transaction.update(rideRef, {'seats': FieldValue.increment(1)});
          }
          transaction.delete(bookingRef);
        });

        // Notify Driver
        NotificationService.sendNotification(
          receiverId: driverId,
          title: "Annulation Reservation",
          body: "$passengerName a annule sa reservation.",
          type: "booking_cancel",
        );
      } else {
        await bookingRef.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reservation annulee/supprimee.")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    }
  }
}
