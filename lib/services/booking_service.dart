import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import '../models/booking.dart';
import '../repositories/booking_repository.dart';
import '../repositories/user_repository.dart';

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

      final bookingRepo = BookingRepository();
      final userRepo = UserRepository();

      final existing = await bookingRepo.findExistingBooking(rideId, user.uid);
      if (existing != null) {
        return const BookingCreateResult(
          BookingCreateStatus.alreadyExists,
          'Vous avez deja reserve ce trajet.',
        );
      }

      String? driverPhone = rideData['phone']?.toString();
      if (driverPhone == null || driverPhone.isEmpty) {
        try {
          driverPhone = await userRepo.fetchPhoneNumber(driverId);
        } catch (_) {
          // Keep driverPhone null if lookup fails
        }
      }

      DateTime? rideDate;
      final dateValue = rideData['date'];
      if (dateValue is DateTime) {
        rideDate = dateValue;
      } else if (dateValue is Timestamp) {
        rideDate = dateValue.toDate();
      }

      final booking = Booking(
        id: '',
        rideId: rideId,
        driverId: driverId,
        passengerId: user.uid,
        passengerName: user.displayName ?? user.email?.split('@')[0] ?? 'Passager',
        passengerPhotoUrl: user.photoURL,
        status: 'pending',
        timestamp: null,
        rideDestination: rideData['destinationName'] ?? 'EST Agadir',
        rideDate: rideDate,
        ridePrice: (rideData['price'] as num?)?.toDouble(),
        driverName: rideData['driverName']?.toString(),
        driverPhotoUrl: rideData['driverPhotoUrl']?.toString(),
        driverPhone: driverPhone,
        departureAddress: rideData['departureAddress']?.toString(),
      );

      await bookingRepo.createBooking(booking);

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
