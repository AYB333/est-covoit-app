import 'package:flutter/material.dart';

import '../../config/translations.dart';
import 'driver_rides_list.dart';
import 'passenger_bookings_list.dart';

class MyRidesTab extends StatelessWidget {
  final int initialTabIndex;

  const MyRidesTab({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final int safeInitialIndex =
        initialTabIndex < 0 ? 0 : (initialTabIndex > 1 ? 1 : initialTabIndex);
    return DefaultTabController(
      length: 2,
      initialIndex: safeInitialIndex,
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
        body: const TabBarView(
          children: [
            DriverRidesList(),
            PassengerBookingsList(),
          ],
        ),
      ),
    );
  }
}
