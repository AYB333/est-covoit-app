import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';

class UserRepository {
  final FirebaseFirestore _db;

  UserRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  Future<UserProfile?> fetchProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromDoc(doc);
  }

  Stream<UserProfile?> streamProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromDoc(doc);
    });
  }

  Future<void> setPhoneNumber(String uid, String phoneNumber) async {
    await _db.collection('users').doc(uid).set({
      'phoneNumber': phoneNumber,
    }, SetOptions(merge: true));
  }

  Future<void> saveFcmToken(String uid, String token) async {
    await _db.collection('users').doc(uid).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
  }

  Future<String?> fetchPhoneNumber(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data();
    return data?['phoneNumber']?.toString();
  }

  Future<void> syncProfilePhoto(String uid, String photoUrl) async {
    final batch = _db.batch();

    final ridesQuery = await _db.collection('rides').where('driverId', isEqualTo: uid).get();
    for (var doc in ridesQuery.docs) {
      batch.update(doc.reference, {'driverPhotoUrl': photoUrl});
    }

    final passengerBookings = await _db.collection('bookings').where('passengerId', isEqualTo: uid).get();
    for (var doc in passengerBookings.docs) {
      batch.update(doc.reference, {'passengerPhotoUrl': photoUrl});
    }

    final driverBookings = await _db.collection('bookings').where('driverId', isEqualTo: uid).get();
    for (var doc in driverBookings.docs) {
      batch.update(doc.reference, {'driverPhotoUrl': photoUrl});
    }

    await batch.commit();
  }
}
