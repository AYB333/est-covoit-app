import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/review.dart';

class ReviewRepository {
  final FirebaseFirestore _db;

  ReviewRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  String _reviewDocId(String bookingId, String reviewerId) => '${bookingId}_$reviewerId';

  Future<Review?> fetchReviewForBooking({
    required String bookingId,
    required String reviewerId,
  }) async {
    final doc = await _db.collection('reviews').doc(_reviewDocId(bookingId, reviewerId)).get();
    if (!doc.exists) return null;
    return Review.fromDoc(doc);
  }

  Future<void> submitReview({
    required String bookingId,
    required String rideId,
    required String reviewerId,
    required String revieweeId,
    required int rating,
    required String comment,
  }) async {
    final reviewRef = _db.collection('reviews').doc(_reviewDocId(bookingId, reviewerId));
    final userRef = _db.collection('users').doc(revieweeId);

    await _db.runTransaction((transaction) async {
      final existingReviewSnap = await transaction.get(reviewRef);
      if (existingReviewSnap.exists) {
        throw StateError('review-exists');
      }

      final userSnap = await transaction.get(userRef);
      final userData = userSnap.data() ?? <String, dynamic>{};
      final oldCount = (userData['ratingCount'] as num?)?.toInt() ?? 0;
      final oldAvg = (userData['ratingAvg'] as num?)?.toDouble() ?? 0.0;

      final newCount = oldCount + 1;
      final newAvg = ((oldAvg * oldCount) + rating) / newCount;

      transaction.set(reviewRef, {
        'bookingId': bookingId,
        'rideId': rideId,
        'reviewerId': reviewerId,
        'revieweeId': revieweeId,
        'rating': rating,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.set(userRef, {
        'ratingCount': newCount,
        'ratingAvg': newAvg,
      }, SetOptions(merge: true));
    });
  }
}
