import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String receiverId;
  final String? senderId;
  final String title;
  final String body;
  final String type;
  final bool read;
  final DateTime? timestamp;

  const AppNotification({
    required this.id,
    required this.receiverId,
    this.senderId,
    required this.title,
    required this.body,
    required this.type,
    required this.read,
    this.timestamp,
  });

  factory AppNotification.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return AppNotification.fromMap(data, id: doc.id);
  }

  factory AppNotification.fromMap(Map<String, dynamic> data, {String id = ''}) {
    final Timestamp? ts = data['timestamp'] as Timestamp?;
    return AppNotification(
      id: id,
      receiverId: data['receiverId']?.toString() ?? '',
      senderId: data['senderId']?.toString(),
      title: data['title']?.toString() ?? '',
      body: data['body']?.toString() ?? '',
      type: data['type']?.toString() ?? '',
      read: data['read'] == true,
      timestamp: ts?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'receiverId': receiverId,
      'senderId': senderId,
      'title': title,
      'body': body,
      'type': type,
      'read': read,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : null,
    };
  }
}
