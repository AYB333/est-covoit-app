import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/translations.dart';
import '../../screens/profile_screen.dart';
import '../user_avatar.dart';

class HomeHeader extends StatelessWidget {
  final String userName;
  final String? photoUrl;
  final VoidCallback onLogout;

  const HomeHeader({
    super.key,
    required this.userName,
    required this.photoUrl,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // --- HEADER CONTAINER ---
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
          // --- LEFT: AVATAR + SALAM + NAME ---
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                },
                child: UserAvatar(
                  userName: userName,
                  imageUrl: photoUrl ?? FirebaseAuth.instance.currentUser?.photoURL,
                  radius: 28,
                  backgroundColor: Colors.white,
                  textColor: scheme.primary,
                  fontSize: 22,
                ),
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
                    userName,
                    style: textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
          // --- RIGHT: LOGOUT ---
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: onLogout,
              tooltip: 'Deconnexion',
            ),
          ),
        ],
      ),
    );
  }
}
