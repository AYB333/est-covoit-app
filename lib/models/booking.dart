import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String id;
  final String rideId;
  final String driverId;
  final String passengerId;
  final String passengerName;
  final String? passengerPhotoUrl;
  final String status;
  final DateTime? timestamp;
  final String rideDestination;
  final DateTime? rideDate;
  final double? ridePrice;
  final String? driverName;
  final String? driverPhotoUrl;
  final String? driverPhone;
  final String? departureAddress;

  const Booking({
    required this.id,
    required this.rideId,
    required this.driverId,
    required this.passengerId,
    required this.passengerName,
    this.passengerPhotoUrl,
    required this.status,
    this.timestamp,
    required this.rideDestination,
    this.rideDate,
    this.ridePrice,
    this.driverName,
    this.driverPhotoUrl,
    this.driverPhone,
    this.departureAddress,
  });

  factory Booking.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return Booking.fromMap(data, id: doc.id);
  }

  factory Booking.fromMap(Map<String, dynamic> data, {String id = ''}) {
    final Timestamp? ts = data['timestamp'] as Timestamp?;
    final Timestamp? rideTs = data['rideDate'] as Timestamp?;
    return Booking(
      id: id,
      rideId: data['rideId']?.toString() ?? '',
      driverId: data['driverId']?.toString() ?? '',
      passengerId: data['passengerId']?.toString() ?? '',
      passengerName: data['passengerName']?.toString() ?? 'Passager',
      passengerPhotoUrl: data['passengerPhotoUrl']?.toString(),
      status: data['status']?.toString() ?? 'pending',
      timestamp: ts?.toDate(),
      rideDestination: data['rideDestination']?.toString() ?? 'EST Agadir',
      rideDate: rideTs?.toDate(),
      ridePrice: (data['ridePrice'] as num?)?.toDouble(),
      driverName: data['driverName']?.toString(),
      driverPhotoUrl: data['driverPhotoUrl']?.toString(),
      driverPhone: data['driverPhone']?.toString(),
      departureAddress: data['departureAddress']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rideId': rideId,
      'driverId': driverId,
      'passengerId': passengerId,
      'passengerName': passengerName,
      'passengerPhotoUrl': passengerPhotoUrl,
      'status': status,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : null,
      'rideDestination': rideDestination,
      'rideDate': rideDate != null ? Timestamp.fromDate(rideDate!) : null,
      'ridePrice': ridePrice,
      'driverName': driverName,
      'driverPhotoUrl': driverPhotoUrl,
      'driverPhone': driverPhone,
      'departureAddress': departureAddress,
    };
  }
}
