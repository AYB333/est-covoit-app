import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:est_covoit/login_screen.dart'; // T2kked mn l-import dyal Login
import 'package:est_covoit/ride_details_screen.dart';
import 'package:est_covoit/find_ride_screen.dart';
import 'package:latlong2/latlong.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName = _getUserName();
    // Default LatLng (Agadir)
    final LatLng defaultStartLocation = LatLng(30.4000, -9.6000);

    return Scaffold(
      appBar: AppBar(
        title: const Text('EST-Covoit'),
        centerTitle: true,
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour, $userName !',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: Column(
                  children: [
                    // CARTE CONDUCTEUR
                    Expanded(
                      child: _buildRoleCard(
                        icon: Icons.directions_car,
                        title: 'Mode Conducteur',
                        subtitle: 'Je propose un trajet',
                        color: Colors.blue,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => RideDetailsScreen(startLocation: defaultStartLocation),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    // CARTE PASSAGER
                    Expanded(
                      child: _buildRoleCard(
                        icon: Icons.person_search,
                        title: 'Mode Passager',
                        subtitle: 'Je cherche un trajet',
                        color: Colors.green,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => FindRideScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      // HNA L-ISLA7: shade50 -> withOpacity(0.1)
      color: color.withOpacity(0.1), 
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 60, color: color),
              const SizedBox(height: 15),
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  // HNA L-ISLA7: shade800 -> color
                  color: color, 
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  // HNA L-ISLA7: shade600 -> withOpacity(0.7)
                  color: color.withOpacity(0.7), 
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}