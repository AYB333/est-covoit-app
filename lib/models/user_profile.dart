import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String id;
  final String? phoneNumber;
  final String? fcmToken;

  const UserProfile({
    required this.id,
    this.phoneNumber,
    this.fcmToken,
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phoneNumber': phoneNumber,
      'fcmToken': fcmToken,
    };
  }
}
