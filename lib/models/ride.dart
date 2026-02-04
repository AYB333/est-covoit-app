import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class Ride {
  final String id;
  final String driverId;
  final String driverName;
  final String? driverPhotoUrl;
  final String vehicleType;
  final double price;
  final int seats;
  final DateTime date;
  final double startLat;
  final double startLng;
  final String? departureAddress;
  final String destinationName;
  final String status;
  final List<LatLng> polylinePoints;
  final double routeDistanceKm;

  const Ride({
    required this.id,
    required this.driverId,
    required this.driverName,
    this.driverPhotoUrl,
    required this.vehicleType,
    required this.price,
    required this.seats,
    required this.date,
    required this.startLat,
    required this.startLng,
    this.departureAddress,
    required this.destinationName,
    required this.status,
    required this.polylinePoints,
    required this.routeDistanceKm,
  });

  factory Ride.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return Ride.fromMap(data, id: doc.id);
  }

  factory Ride.fromMap(Map<String, dynamic> data, {String id = ''}) {
    final Timestamp? ts = data['date'] as Timestamp?;
    final List<dynamic> rawPoints = (data['polylinePoints'] as List<dynamic>?) ?? [];
    final points = rawPoints
        .map((p) => LatLng(
              (p['latitude'] as num?)?.toDouble() ?? 0.0,
              (p['longitude'] as num?)?.toDouble() ?? 0.0,
            ))
        .where((p) => p.latitude != 0.0 || p.longitude != 0.0)
        .toList();

    return Ride(
      id: id,
      driverId: data['driverId']?.toString() ?? '',
      driverName: data['driverName']?.toString() ?? 'Utilisateur',
      driverPhotoUrl: data['driverPhotoUrl']?.toString(),
      vehicleType: data['vehicleType']?.toString() ?? 'Voiture',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      seats: (data['seats'] as num?)?.toInt() ?? 0,
      date: ts?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      startLat: (data['startLat'] as num?)?.toDouble() ?? 0.0,
      startLng: (data['startLng'] as num?)?.toDouble() ?? 0.0,
      departureAddress: data['departureAddress']?.toString(),
      destinationName: data['destinationName']?.toString() ?? 'EST Agadir',
      status: data['status']?.toString() ?? 'available',
      polylinePoints: points,
      routeDistanceKm: (data['routeDistanceKm'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'driverName': driverName,
      'driverPhotoUrl': driverPhotoUrl,
      'vehicleType': vehicleType,
      'price': price,
      'seats': seats,
      'date': Timestamp.fromDate(date),
      'startLat': startLat,
      'startLng': startLng,
      'departureAddress': departureAddress,
      'destinationName': destinationName,
      'status': status,
      'polylinePoints': polylinePoints
          .map((p) => {'latitude': p.latitude, 'longitude': p.longitude})
          .toList(),
      'routeDistanceKm': routeDistanceKm,
    };
  }
}
