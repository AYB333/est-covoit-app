import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../config/translations.dart';
import '../../screens/add_ride_screen.dart';
import 'package:est_covoit/screens/ride_details_screen.dart';
import 'home_header.dart';
import 'home_role_card.dart';

class HomeTabView extends StatelessWidget {
  final String userName;
  final String? photoUrl;
  final String initialAddress;
  final VoidCallback onLogout;

  const HomeTabView({
    super.key,
    required this.userName,
    required this.photoUrl,
    required this.initialAddress,
    required this.onLogout,
  });

  Stream<int> _availableRidesCountStream() {
    return FirebaseFirestore.instance
        .collection('rides')
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 1)),
          ),
        )
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Stream<int> _myRidesCountStream(String userId) {
    return FirebaseFirestore.instance
        .collection('rides')
        .where('driverId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Stream<int> _myBookingsCountStream(String userId) {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('passengerId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    final LatLng defaultStartLocation = const LatLng(30.4000, -9.6000);
    final scheme = Theme.of(context).colorScheme;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Column(
      children: [
        HomeHeader(
          userName: userName,
          photoUrl: photoUrl,
          onLogout: onLogout,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Translations.getText(context, 'home_stats'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        countStream: _availableRidesCountStream(),
                        label: Translations.getText(context, 'available_trips'),
                        icon: Icons.route_rounded,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatTile(
                        countStream: currentUserId == null
                            ? Stream<int>.value(0)
                            : _myRidesCountStream(currentUserId),
                        label: Translations.getText(context, 'my_ads'),
                        icon: Icons.directions_car_filled_rounded,
                        color: scheme.secondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatTile(
                        countStream: currentUserId == null
                            ? Stream<int>.value(0)
                            : _myBookingsCountStream(currentUserId),
                        label: Translations.getText(context, 'my_bookings'),
                        icon: Icons.bookmark_added_rounded,
                        color: scheme.tertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: HomeRoleCard(
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
                            initialAddress: initialAddress,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: HomeRoleCard(
                    title: Translations.getText(context, 'passenger_card'),
                    subtitle: Translations.getText(context, 'passenger_subtitle'),
                    icon: Icons.search,
                    color: scheme.secondary,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddRideScreen(isDriver: false),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final Stream<int> countStream;
  final String label;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.countStream,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          StreamBuilder<int>(
            stream: countStream,
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return Text(
                '$count',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              );
            },
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
