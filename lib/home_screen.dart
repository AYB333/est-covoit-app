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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue[800],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.only(top: 60, left: 25, right: 25, bottom: 25), // Padding ajusté pour SafeArea
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
               // Avatar
               UserAvatar(
                 userName: _getUserName(),
                 imageUrl: FirebaseAuth.instance.currentUser?.photoURL,
                 radius: 28,
                 backgroundColor: Colors.white,
                 textColor: Colors.blue[800],
                 fontSize: 22,
               ),
               const SizedBox(width: 15),
               Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(Translations.getText(context, 'home_title'), style: const TextStyle(fontSize: 16, color: Colors.white70)),
                   Text(
                     _getUserName(),
                     style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                   ),
                 ],
               ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _showLogoutConfirmation,
            tooltip: "Déconnexion",
          ),
        ],
      ),
    );
  }

  // --- TAB 1: HOME VIEW ---
  Widget _buildHomeView() {
    final LatLng defaultStartLocation = LatLng(30.4000, -9.6000);
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
                    color: Colors.blue[800]!,
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
                    color: Colors.green[600]!,
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(Translations.getText(context, 'my_activities')),
          backgroundColor: Colors.blue[800],
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          centerTitle: true,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: Translations.getText(context, 'my_ads')),     // Ce que j'ai publié (Conducteur)
              Tab(text: Translations.getText(context, 'my_bookings')), // Ce que j'ai demandé (Passager)
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
                        backgroundColor: Colors.blue[50],
                        textColor: Colors.blue[800],
                    ),
                    trailing: Text(
                      "$seats P. Disp.",
                      style: TextStyle(fontWeight: FontWeight.bold, color: seats > 0 ? Colors.green : Colors.red),
                    ),
                  ),
                  const Divider(height: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Edit
                      TextButton.icon(
                        icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                        label: Text(Translations.getText(context, 'edit'), style: const TextStyle(color: Colors.blue)),
                        onPressed: () {
                          // Navigate to Edit Mode
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
                      // Delete
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        label: Text(Translations.getText(context, 'delete'), style: const TextStyle(color: Colors.red)),
                        onPressed: () => _deleteRide(rideDoc.id),
                      ),
                      // Requests
                      // Requests with Badge
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
                                  backgroundColor: Colors.red,
                                  child: const Icon(Icons.people_alt_outlined, size: 18),
                                )
                              : const Icon(Icons.people_alt_outlined, size: 18),
                            label: Text(
                              Translations.getText(context, 'requests'), 
                              style: TextStyle(
                                fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
                                color: count > 0 ? Colors.blue[900] : null
                              )
                            ),
                            onPressed: () => _showRequestsModal(context, rideDoc.id),
                          );
                        }
                      ),
                    ],
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
              child: Text("Erreur: ${snapshot.error}", style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
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
                statusColor = Colors.green;
                statusText = Translations.getText(context, 'accepted');
                statusIcon = Icons.check_circle;
                break;
              case 'rejected':
                statusColor = Colors.red;
                statusText = Translations.getText(context, 'rejected');
                statusIcon = Icons.cancel;
                break;
              case 'pending':
              default:
                statusColor = Colors.orange;
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
                               textColor: Colors.blue,
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
                                   textColor: Colors.blue,
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
                                   style: const TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.bold),
                                 ),
                             ],
                           ),
                         ),
                         Column(
                           crossAxisAlignment: CrossAxisAlignment.end,
                           children: [
                             Text(
                               "${b['ridePrice'] ?? '?'} MAD",
                               style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
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
                             icon: const Icon(Icons.chat_bubble_outline, size: 20, color: Colors.blue),
                             label: Text(Translations.getText(context, 'discuss'), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                           ),
                         
                         // Delete/Cancel Button for all statuses
                         TextButton.icon(
                           onPressed: () => _deleteBooking(bookingDoc.id, status == 'accepted'),
                           icon: Icon(
                             status == 'accepted' ? Icons.delete_forever : Icons.delete_outline, 
                             size: 20, 
                             color: Colors.red
                           ),
                           label: Text(
                             status == 'pending' ? Translations.getText(context, 'cancel') : Translations.getText(context, 'delete'),
                             style: const TextStyle(color: Colors.red),
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
            child: const Text("Confirmer", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
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
    final bool? confirm = await showDialog<bool>(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer"),
        content: const Text("Voulez-vous supprimer ce trajet ?\nCela annulera toutes les réservations associées."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Supprimer", style: TextStyle(color: Colors.red))
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
                                          color: status == 'pending' ? Colors.orange : status == 'accepted' ? Colors.green : Colors.red,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (status == 'pending') ...[
                                  IconButton(
                                    icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                                    onPressed: () => _handleBooking(req.id, rideId, true, rData['passengerId']),
                                    tooltip: "Accepter",
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
                                    onPressed: () => _handleBooking(req.id, rideId, false, rData['passengerId']),
                                    tooltip: "Refuser",
                                  ),
                                ] else if (status == 'accepted') ...[
                                  IconButton(
                                    icon: const Icon(Icons.chat_bubble, color: Colors.blue),
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
                                  const Icon(Icons.check_circle_outline, color: Colors.green),
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: Theme.of(context).cardColor,
          selectedItemColor: Colors.blue[800],
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Accueil',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_rounded),
              label: 'Mes Activités',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Paramètres',
            ),
          ],
        ),
      ),
    );
  }

  // Widget Design Card (Helper)
  Widget _buildRoleCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
          ],
          border: Border.all(color: color.withOpacity(0.1), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 5),
                  Text(subtitle, style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[300], size: 18),
          ],
        ),
      ),
    );
  }
}



