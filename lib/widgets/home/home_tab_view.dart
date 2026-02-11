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

  @override
  Widget build(BuildContext context) {
    final LatLng defaultStartLocation = LatLng(30.4000, -9.6000);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        HomeHeader(
          userName: userName,
          photoUrl: photoUrl,
          onLogout: onLogout,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
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
                const SizedBox(height: 20),
                Expanded(
                  child: HomeRoleCard(
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
}
