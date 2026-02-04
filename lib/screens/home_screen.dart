import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../config/translations.dart';
import '../services/notification_service.dart';
import '../widgets/home/home_tab_view.dart';
import '../widgets/home/my_rides_tab.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

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
    return 'Utilisateur';
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
              child: Text(
                Translations.getText(context, 'logout_btn'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- TAB 3: SETTINGS ---
  Widget _buildSettingsView() {
    // SettingsScreen deja 3ndou Scaffold w AppBar dyalo, donc kan3ytou lih nichan
    return const SettingsScreen();
  }

  // --- BUILD MAIN ---
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // Liste des pages
    final List<Widget> pages = [
      HomeTabView(
        userName: _getUserName(),
        photoUrl: user?.photoURL,
        initialAddress: _addressController.text,
        onLogout: _showLogoutConfirmation,
      ),
      const MyRidesTab(),
      _buildSettingsView(),
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
}
