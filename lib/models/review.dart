import 'package:cloud_firestore/cloud_firestore.dart';

// --- MODEL: REVIEW ---
class Review {
  final String id;
  final String bookingId;
  final String rideId;
  final String reviewerId;
  final String revieweeId;
  final int rating;
  final String comment;
  final DateTime? createdAt;

  const Review({
    required this.id,
    required this.bookingId,
    required this.rideId,
    required this.reviewerId,
    required this.revieweeId,
    required this.rating,
    required this.comment,
    this.createdAt,
  });

  // --- FROM FIRESTORE DOC ---
  factory Review.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return Review.fromMap(data, id: doc.id);
  }

  // --- FROM MAP ---
  factory Review.fromMap(Map<String, dynamic> data, {String id = ''}) {
    final createdAtTs = data['createdAt'] as Timestamp?;
    return Review(
      id: id,
      bookingId: data['bookingId']?.toString() ?? '',
      rideId: data['rideId']?.toString() ?? '',
      reviewerId: data['reviewerId']?.toString() ?? '',
      revieweeId: data['revieweeId']?.toString() ?? '',
      rating: (data['rating'] as num?)?.toInt() ?? 0,
      comment: data['comment']?.toString() ?? '',
      createdAt: createdAtTs?.toDate(),
    );
  }

  // --- TO MAP ---
  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'rideId': rideId,
      'reviewerId': reviewerId,
      'revieweeId': revieweeId,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }
}
