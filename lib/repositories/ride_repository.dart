import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ride.dart';

class RideRepository {
  final FirebaseFirestore _db;

  RideRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  Stream<List<Ride>> streamDriverRides(String driverId) {
    return _db
        .collection('rides')
        .where('driverId', isEqualTo: driverId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Ride.fromDoc).toList());
  }

  Stream<List<Ride>> streamAvailableRidesFrom(DateTime from) {
    return _db
        .collection('rides')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .orderBy('date', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(Ride.fromDoc).toList());
  }

  Future<void> createRide(Ride ride) async {
    final data = ride.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();
    await _db.collection('rides').add(data);
  }

  Future<void> updateRide(String rideId, Ride ride) async {
    final data = ride.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('rides').doc(rideId).update(data);
  }

  Future<Ride?> fetchRide(String rideId) async {
    final doc = await _db.collection('rides').doc(rideId).get();
    if (!doc.exists) return null;
    return Ride.fromDoc(doc);
  }

  Stream<Ride?> streamRide(String rideId) {
    return _db.collection('rides').doc(rideId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Ride.fromDoc(doc);
    });
  }

  Future<void> updateSeats(String rideId, int seats) async {
    await _db.collection('rides').doc(rideId).update({'seats': seats});
  }

  Future<void> incrementSeats(String rideId, int delta) async {
    await _db.collection('rides').doc(rideId).update({'seats': FieldValue.increment(delta)});
  }

  Future<void> deleteRideAndBookings(String rideId) async {
    final batch = _db.batch();
    final rideRef = _db.collection('rides').doc(rideId);

    final bookingsQuery = await _db.collection('bookings').where('rideId', isEqualTo: rideId).get();
    for (var doc in bookingsQuery.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(rideRef);
    await batch.commit();
  }
}
