import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/translations.dart';
import '../models/review.dart';
import '../models/ride.dart';
import '../models/user_profile.dart';
import '../repositories/user_repository.dart';
import '../widgets/user_avatar.dart';

// --- SCREEN: PUBLIC PROFILE ---
class PublicProfileScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String? photoUrl;

  const PublicProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.photoUrl,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  // --- FUTURE: STATS DATA ---
  late final Future<_PublicProfileData> _profileDataFuture;

  @override
  void initState() {
    super.initState();
    // --- LOAD STATS ---
    _profileDataFuture = _loadProfileData();
  }

  // --- FETCH PROFILE STATS (RIDES / BOOKINGS / REVIEWS) ---
  Future<_PublicProfileData> _loadProfileData() async {
    final db = FirebaseFirestore.instance;

    final ridesSnap =
        await db.collection('rides').where('driverId', isEqualTo: widget.userId).get();
    final acceptedDriverBookingsSnap = await db
        .collection('bookings')
        .where('driverId', isEqualTo: widget.userId)
        .where('status', isEqualTo: 'accepted')
        .get();
    final reviewsSnap = await db
        .collection('reviews')
        .where('revieweeId', isEqualTo: widget.userId)
        .limit(30)
        .get();

    final rides = ridesSnap.docs.map((doc) => Ride.fromDoc(doc)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final reviews = reviewsSnap.docs.map((doc) => Review.fromDoc(doc)).toList()
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    final visibleReviews =
        reviews.where((review) => review.comment.trim().isNotEmpty).take(5).toList();

    return _PublicProfileData(
      ridesPublished: rides.length,
      acceptedTripsAsDriver: acceptedDriverBookingsSnap.docs.length,
      recentRides: rides.take(5).toList(),
      recentReviews: visibleReviews,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      // --- APPBAR ---
      appBar: AppBar(
        title: Text(Translations.getText(context, 'profile')),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
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
      ),
      // --- BODY: STATS + REVIEWS ---
      body: FutureBuilder<_PublicProfileData>(
        future: _profileDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "${Translations.getText(context, 'error_prefix')} ${snapshot.error}",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final data = snapshot.data ??
              const _PublicProfileData(
                ridesPublished: 0,
                acceptedTripsAsDriver: 0,
                recentRides: <Ride>[],
                recentReviews: <Review>[],
              );

          // --- STREAM: RATING ---
          return StreamBuilder<UserProfile?>(
            stream: UserRepository().streamProfile(widget.userId),
            builder: (context, userSnap) {
              final profile = userSnap.data;
              final double ratingAvg = profile?.ratingAvg ?? 0;
              final int ratingCount = profile?.ratingCount ?? 0;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // --- HEADER CARD ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          scheme.primary.withValues(alpha: 0.18),
                          scheme.secondary.withValues(alpha: 0.12),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        UserAvatar(
                          userName: widget.userName,
                          imageUrl: widget.photoUrl,
                          radius: 34,
                          backgroundColor: Colors.white,
                          textColor: scheme.primary,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.star_rounded, size: 18, color: scheme.tertiary),
                                  const SizedBox(width: 4),
                                  Text(
                                    ratingCount > 0
                                        ? '${ratingAvg.toStringAsFixed(1)} ($ratingCount)'
                                        : Translations.getText(context, 'no_reviews'),
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // --- STATS CARDS ---
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: Translations.getText(context, 'rides_published'),
                          value: data.ridesPublished.toString(),
                          icon: Icons.directions_car_filled_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: Translations.getText(context, 'accepted_bookings_count'),
                          value: data.acceptedTripsAsDriver.toString(),
                          icon: Icons.check_circle_outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // --- SECTION: RECENT RIDES ---
                  _SectionCard(
                    title: Translations.getText(context, 'recent_rides'),
                    icon: Icons.route_rounded,
                    child: data.recentRides.isEmpty
                        ? _buildEmptyText(context, Translations.getText(context, 'no_trips'))
                        : Column(
                            children: data.recentRides.map((ride) {
                              final departure = ride.departureAddress ??
                                  Translations.getText(context, 'departure');
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerLowest.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(Icons.route, color: scheme.primary),
                                  title: Text(
                                    '$departure \u2192 ${ride.destinationName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(ride.date)),
                                  trailing: Text(
                                    '${ride.price.toStringAsFixed(1)} MAD',
                                    style: TextStyle(
                                      color: scheme.secondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 14),
                  // --- SECTION: RECENT REVIEWS ---
                  _SectionCard(
                    title: Translations.getText(context, 'latest_reviews'),
                    icon: Icons.rate_review_outlined,
                    child: data.recentReviews.isEmpty
                        ? _buildEmptyText(context, Translations.getText(context, 'no_reviews'))
                        : Column(
                            children: data.recentReviews.map((review) {
                              final date = review.createdAt;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerLowest.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(Icons.star, color: scheme.tertiary),
                                  title: Text(
                                    review.comment,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    date != null ? DateFormat('dd/MM/yyyy').format(date) : '',
                                  ),
                                  trailing: Text(
                                    '${review.rating}/5',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // --- EMPTY STATE TEXT ---
  Widget _buildEmptyText(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

// --- UI: SECTION CARD ---
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// --- UI: STAT CARD ---
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// --- MODEL: PUBLIC PROFILE DATA ---
class _PublicProfileData {
  final int ridesPublished;
  final int acceptedTripsAsDriver;
  final List<Ride> recentRides;
  final List<Review> recentReviews;

  const _PublicProfileData({
    required this.ridesPublished,
    required this.acceptedTripsAsDriver,
    required this.recentRides,
    required this.recentReviews,
  });
}
