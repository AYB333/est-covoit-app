import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart'; 
import 'login_screen.dart';
import 'ride_details_screen.dart'; // Import dyal Conducteur
import 'find_ride_screen.dart';   // Import dyal Passager

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Fonction bach njibou smiya d l-utilisateur
  String _getUserName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!;
    } else if (user != null && user.email != null) {
      String name = user.email!.split('@')[0];
      // N-kbbrou l-7rf l-lowel
      return name[0].toUpperCase() + name.substring(1);
    }
    return "Utilisateur";
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName = _getUserName();
    final LatLng defaultStartLocation = LatLng(30.4000, -9.6000); // Agadir

    return Scaffold(
      backgroundColor: Colors.grey[50], // Arrière-plan khfif
      appBar: null,
      body: Column(
        children: [
          SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue[800],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              padding: const EdgeInsets.all(25),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Bonjour,", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w300)),
                      Text(
                        userName,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.logout, color: Colors.white),
                    ),
                    onPressed: _logout,
                    tooltip: "Se déconnecter",
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    // --- CARTE CONDUCTEUR ---
                    Expanded(
                      child: _buildRoleCard(
                        context,
                        title: "Je suis Conducteur",
                        subtitle: "Publier un trajet, partager les frais.",
                        icon: Icons.directions_car,
                        color: Colors.blue[800]!,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RideDetailsScreen(startLocation: defaultStartLocation),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // --- CARTE PASSAGER ---
                    Expanded(
                      child: _buildRoleCard(
                        context,
                        title: "Je suis Passager",
                        subtitle: "Trouver un trajet vers l'EST.",
                        icon: Icons.search,
                        color: Colors.green[600]!,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const FindRideScreen()),
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
      ),
    );
  }

  // Design dyal Carte (NADI)
  Widget _buildRoleCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, // Abyad bach yban nqi
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
          border: Border.all(color: color.withOpacity(0.1), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1), // Couleur khfifaoura l-icon
                shape: BoxShape.circle,
              ),
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
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
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