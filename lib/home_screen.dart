import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart';
import 'ride_details_screen.dart';
import 'add_ride_screen.dart';
import 'settings_screen.dart';
import 'translations.dart';
import 'chat_screen.dart';
import 'user_avatar.dart';
import 'notification_service.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Start listening for notifications for the current user
    NotificationService().startListening();
  }

  // --- HELPER: Get User Name ---
  String _getUserName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!;
    } else if (user != null && user.email != null) {
      String name = user.email!.split('@')[0];
      return name[0].toUpperCase() + name.substring(1);
    }
    return "Utilisateur";
  }

  // --- LOGOUT LOGIC ---
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  void _showLogoutConfirmation() {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(Translations.getText(context, 'logout')),
          content: Text(Translations.getText(context, 'logout_confirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(Translations.getText(context, 'cancel_btn')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _logout();
              },
              style: ElevatedButton.styleFrom(backgroundColor: scheme.error),
              child: Text(Translations.getText(context, 'logout_btn'), style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- HEADER SPECIAL (Bonjour + Logout) ---
  // Hada ghayban GHIR f l-Home
  // --- HEADER SPECIAL (Bonjour + Logout) ---
  // Hada ghayban GHIR f l-Home
    Widget _buildHomeHeader() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              UserAvatar(
                userName: _getUserName(),
                imageUrl: FirebaseAuth.instance.currentUser?.photoURL,
                radius: 28,
                backgroundColor: Colors.white,
                textColor: scheme.primary,
                fontSize: 22,
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Translations.getText(context, 'home_title'),
                    style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                  Text(
                    _getUserName(),
                    style: textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: _showLogoutConfirmation,
              tooltip: 'Deconnexion',
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: HOME VIEW ---
  Widget _buildHomeView() {
    final LatLng defaultStartLocation = LatLng(30.4000, -9.6000);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Header hna dakhil l-page Home
        _buildHomeHeader(),
        
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Expanded(
                  child: _buildRoleCard(
                    context,
                    title: Translations.getText(context, 'driver_card'),
                    subtitle: Translations.getText(context, 'driver_subtitle'),
                    icon: Icons.directions_car,
                    color: scheme.primary,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RideDetailsScreen(
                            startLocation: defaultStartLocation,
                            initialAddress: _addressController.text,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: _buildRoleCard(
                    context,
                    title: Translations.getText(context, 'passenger_card'),
                    subtitle: Translations.getText(context, 'passenger_subtitle'),
                    icon: Icons.search,
                    color: scheme.secondary,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AddRideScreen(isDriver: false)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- TAB 2: MES TRAJETS VIEW (Driver & Passenger) ---
  Widget _buildMyRidesView() {
    final scheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(Translations.getText(context, 'my_activities')),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
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
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: Translations.getText(context, 'my_ads')),
              Tab(text: Translations.getText(context, 'my_bookings')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDriverRides(),
            _buildPassengerBookings(),
          ],
        ),
      ),
    );
  }

  // --- SUB-VIEW: Driver Rides ---
  Widget _buildDriverRides() {
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
                      maxLines: 1, overflow: TextOverflow.ellipsis,
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
                                    data['startLng'] ?? -9.6000
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
                                  color: count > 0 ? scheme.primary : null
                                )
                              ),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              ),
                              onPressed: () => _showRequestsModal(context, rideDoc.id),
                            );
                          }
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

  // --- SUB-VIEW: Passenger Bookings ---
  Widget _buildPassengerBookings() {
    final scheme = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("Non connecté"));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('passengerId', isEqualTo: user.uid)
          .snapshots(),
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
            String route = "${b['departureAddress'] ?? 'Départ'} → ${b['rideDestination'] ?? 'EST'}";
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
                                 style: TextStyle(color: Colors.grey[700], fontSize: 13)
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
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    bookingId: bookingDoc.id,
                                    otherUserName: b['driverName'] ?? 'Conducteur',
                                    otherUserId: b['driverId'],
                                    otherUserPhotoUrl: b['driverPhotoUrl'],
                                  )
                                ));
                             },
                             icon: Icon(Icons.chat_bubble_outline, size: 20, color: scheme.primary),
                             label: Text(Translations.getText(context, 'discuss'), style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold)),
                           ),
                         
                         // Delete/Cancel Button for all statuses
                         TextButton.icon(
                           onPressed: () => _deleteBooking(bookingDoc.id, status == 'accepted'),
                           icon: Icon(
                             status == 'accepted' ? Icons.delete_forever : Icons.delete_outline, 
                             size: 20, 
                             color: scheme.error
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
            child: Text("Confirmer", style: TextStyle(color: scheme.error, fontWeight: FontWeight.bold))
          )
        ],
      )
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
            child: Text("Supprimer", style: TextStyle(color: scheme.error))
          )
        ],
      )
    );

    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final rideRef = FirebaseFirestore.instance.collection('rides').doc(rideId);
      
      // Get all bookings for this ride
      final bookingsQuery = await FirebaseFirestore.instance.collection('bookings').where('rideId', isEqualTo: rideId).get();
      
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
                  stream: FirebaseFirestore.instance
                      .collection('bookings')
                      .where('rideId', isEqualTo: rideId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Aucune demande."));

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
                                      Text(passengerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text(
                                        status == 'pending' ? 'En attente' : status == 'accepted' ? 'Accepté' : 'Refusé',
                                        style: TextStyle(
                                          color: status == 'pending' ? scheme.tertiary : status == 'accepted' ? scheme.secondary : scheme.error,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500
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
                                      Navigator.push(context, MaterialPageRoute(
                                        builder: (_) => ChatScreen(
                                          bookingId: req.id,
                                          otherUserName: passengerName,
                                          otherUserId: rData['passengerId'],
                                          otherUserPhotoUrl: rData['passengerPhotoUrl'],
                                        )
                                      ));
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
// --- TAB 3: SETTINGS ---
  Widget _buildSettingsView() {
    // SettingsScreen deja 3ndou Scaffold w AppBar dyalo, donc kan3ytou lih nichan
    return const SettingsScreen(); 
  }

  // --- BUILD MAIN ---
  @override
  Widget build(BuildContext context) {
    // Liste des pages
    final List<Widget> pages = [
      _buildHomeView(),      // Header Zre9 Kayn Hna
      _buildMyRidesView(),   // AppBar "Mes Trajets"
      _buildSettingsView(),  // AppBar "Paramètres" (mn SettingsScreen)
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Body kay-tbeddel 3la 7ssab l-index
      body: pages[_currentIndex],

      // Navigation Bar l-ta7t
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_rounded),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_rounded),
            label: 'Mes activites',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Parametres',
          ),
        ],
      ),
    );
  }

    // Widget Design Card (Helper)
  Widget _buildRoleCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, 8))
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: Colors.white),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: textTheme.titleMedium?.copyWith(color: color)),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: scheme.onSurfaceVariant, size: 18),
          ],
        ),
      ),
    );
  }
}



