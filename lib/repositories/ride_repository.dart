import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ride.dart';

// --- REPO: RIDES ---
class RideRepository {
  final FirebaseFirestore _db;

  RideRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  // --- STREAM: RIDES DYAL DRIVER ---
  Stream<List<Ride>> streamDriverRides(String driverId) {
    return _db
        .collection('rides')
        .where('driverId', isEqualTo: driverId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Ride.fromDoc).toList());
  }

  // --- STREAM: RIDES AVAILABLE FROM DATE ---
  Stream<List<Ride>> streamAvailableRidesFrom(DateTime from) {
    return _db
        .collection('rides')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .orderBy('date', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(Ride.fromDoc).toList());
  }

  // --- CREATE RIDE ---
  Future<void> createRide(Ride ride) async {
    final data = ride.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();
    await _db.collection('rides').add(data);
  }

  // --- UPDATE RIDE ---
  Future<void> updateRide(String rideId, Ride ride) async {
    final data = ride.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('rides').doc(rideId).update(data);
  }

  // --- FETCH RIDE BY ID ---
  Future<Ride?> fetchRide(String rideId) async {
    final doc = await _db.collection('rides').doc(rideId).get();
    if (!doc.exists) return null;
    return Ride.fromDoc(doc);
  }

  // --- STREAM: RIDE BY ID ---
  Stream<Ride?> streamRide(String rideId) {
    return _db.collection('rides').doc(rideId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Ride.fromDoc(doc);
    });
  }

  // --- UPDATE SEATS ---
  Future<void> updateSeats(String rideId, int seats) async {
    await _db.collection('rides').doc(rideId).update({'seats': seats});
  }

  // --- INCREMENT SEATS ---
  Future<void> incrementSeats(String rideId, int delta) async {
    await _db.collection('rides').doc(rideId).update({'seats': FieldValue.increment(delta)});
  }

  // --- DELETE RIDE + RELATED BOOKINGS ---
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
