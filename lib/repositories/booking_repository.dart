import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/booking.dart';

class BookingRepository {
  final FirebaseFirestore _db;

  BookingRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  Stream<List<Booking>> streamPassengerBookings(String passengerId) {
    return _db
        .collection('bookings')
        .where('passengerId', isEqualTo: passengerId)
        .snapshots()
        .map((snap) => snap.docs.map(Booking.fromDoc).toList());
  }

  Stream<List<Booking>> streamRideBookings(String rideId) {
    return _db
        .collection('bookings')
        .where('rideId', isEqualTo: rideId)
        .snapshots()
        .map((snap) => snap.docs.map(Booking.fromDoc).toList());
  }

  Stream<Booking?> streamBooking(String bookingId) {
    return _db.collection('bookings').doc(bookingId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Booking.fromDoc(doc);
    });
  }

  Future<Booking?> fetchBooking(String bookingId) async {
    final doc = await _db.collection('bookings').doc(bookingId).get();
    if (!doc.exists) return null;
    return Booking.fromDoc(doc);
  }

  Stream<List<Booking>> streamPendingBookings(String rideId) {
    return _db
        .collection('bookings')
        .where('rideId', isEqualTo: rideId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map(Booking.fromDoc).toList());
  }

  Future<List<Booking>> fetchBookingsForRide(String rideId) async {
    final snap = await _db.collection('bookings').where('rideId', isEqualTo: rideId).get();
    return snap.docs.map(Booking.fromDoc).toList();
  }

  Future<Booking?> findExistingBooking(String rideId, String passengerId) async {
    final snap = await _db
        .collection('bookings')
        .where('rideId', isEqualTo: rideId)
        .where('passengerId', isEqualTo: passengerId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Booking.fromDoc(snap.docs.first);
  }

  Future<void> createBooking(Booking booking) async {
    final data = booking.toMap();
    data['timestamp'] = FieldValue.serverTimestamp();
    await _db.collection('bookings').add(data);
  }

  Future<void> updateStatus(String bookingId, String status) async {
    await _db.collection('bookings').doc(bookingId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteBooking(String bookingId) async {
    await _db.collection('bookings').doc(bookingId).delete();
  }

  Future<void> acceptBookingWithSeatUpdate({
    required String bookingId,
    required String rideId,
  }) async {
    final rideRef = _db.collection('rides').doc(rideId);
    final bookingRef = _db.collection('bookings').doc(bookingId);

    await _db.runTransaction((transaction) async {
      final rideSnap = await transaction.get(rideRef);
      if (!rideSnap.exists) throw StateError('ride-missing');

      final bookingSnap = await transaction.get(bookingRef);
      if (!bookingSnap.exists) throw StateError('booking-missing');

      final bookingData = bookingSnap.data() as Map<String, dynamic>;
      final status = bookingData['status'] ?? 'pending';
      if (status != 'pending') throw StateError('booking-not-pending');

      final seats = (rideSnap.data()?['seats'] as num?)?.toInt() ?? 0;
      if (seats <= 0) throw StateError('no-seats');

      transaction.update(bookingRef, {
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(rideRef, {'seats': seats - 1});
    });
  }

  Future<void> rejectBooking(String bookingId) async {
    await _db.collection('bookings').doc(bookingId).update({
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteBookingAndRestoreSeat({
    required String bookingId,
    required String rideId,
  }) async {
    final rideRef = _db.collection('rides').doc(rideId);
    final bookingRef = _db.collection('bookings').doc(bookingId);

    await _db.runTransaction((transaction) async {
      final rideSnap = await transaction.get(rideRef);
      if (rideSnap.exists) {
        transaction.update(rideRef, {'seats': FieldValue.increment(1)});
      }
      transaction.delete(bookingRef);
    });
  }
}
