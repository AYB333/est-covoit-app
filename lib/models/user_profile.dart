import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String id;
  final String? phoneNumber;
  final String? fcmToken;
  final double ratingAvg;
  final int ratingCount;

  const UserProfile({
    required this.id,
    this.phoneNumber,
    this.fcmToken,
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
  });

  factory UserProfile.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return UserProfile.fromMap(data, id: doc.id);
  }

  factory UserProfile.fromMap(Map<String, dynamic> data, {String id = ''}) {
    return UserProfile(
      id: id,
      phoneNumber: data['phoneNumber']?.toString(),
      fcmToken: data['fcmToken']?.toString(),
      ratingAvg: (data['ratingAvg'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phoneNumber': phoneNumber,
      'fcmToken': fcmToken,
      'ratingAvg': ratingAvg,
      'ratingCount': ratingCount,
    };
  }
}
