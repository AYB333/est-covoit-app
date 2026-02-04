import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

enum BookingCreateStatus { success, alreadyExists, error, invalidData }

class BookingCreateResult {
  final BookingCreateStatus status;
  final String message;
  final Object? error;

  const BookingCreateResult(this.status, this.message, [this.error]);
}

class BookingService {
  static Future<BookingCreateResult> reserveRide({
    required User user,
    required String rideId,
    required Map<String, dynamic> rideData,
  }) async {
    try {
      final driverId = rideData['driverId']?.toString();
      if (driverId == null || driverId.isEmpty) {
        return const BookingCreateResult(
          BookingCreateStatus.invalidData,
          'Donnees du trajet manquantes.',
        );
      }

      final existing = await FirebaseFirestore.instance
          .collection('bookings')
          .where('rideId', isEqualTo: rideId)
          .where('passengerId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return const BookingCreateResult(
          BookingCreateStatus.alreadyExists,
          'Vous avez deja reserve ce trajet.',
        );
      }

      String? driverPhone = rideData['phone']?.toString();
      if (driverPhone == null || driverPhone.isEmpty) {
        try {
          final driverDoc = await FirebaseFirestore.instance.collection('users').doc(driverId).get();
          final driverData = driverDoc.data();
          if (driverData != null && driverData['phoneNumber'] != null) {
            driverPhone = driverData['phoneNumber'].toString();
          }
        } catch (_) {
          // Keep driverPhone null if lookup fails
        }
      }

      await FirebaseFirestore.instance.collection('bookings').add({
        'rideId': rideId,
        'driverId': driverId,
        'passengerId': user.uid,
        'passengerName': user.displayName ?? user.email?.split('@')[0] ?? 'Passager',
        'passengerPhotoUrl': user.photoURL,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'rideDestination': rideData['destinationName'] ?? 'EST Agadir',
        'rideDate': rideData['date'],
        'ridePrice': rideData['price'],
        'driverName': rideData['driverName'],
        'driverPhotoUrl': rideData['driverPhotoUrl'],
        'driverPhone': driverPhone,
        'departureAddress': rideData['departureAddress'],
      });

      NotificationService.sendNotification(
        receiverId: driverId,
        title: 'Nouvelle Reservation !',
        body: "${user.displayName ?? 'Un passager'} a reserve une place.",
        type: 'booking_request',
      );

      return const BookingCreateResult(
        BookingCreateStatus.success,
        "Demande envoyee ! Verifiez 'Mes Trajets'.",
      );
    } catch (e) {
      return BookingCreateResult(
        BookingCreateStatus.error,
        'Erreur reservation.',
        e,
      );
    }
  }
}
