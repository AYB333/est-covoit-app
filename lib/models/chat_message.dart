import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final DateTime? timestamp;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    this.timestamp,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return ChatMessage.fromMap(data, id: doc.id);
  }

  factory ChatMessage.fromMap(Map<String, dynamic> data, {String id = ''}) {
    final Timestamp? ts = data['timestamp'] as Timestamp?;
    return ChatMessage(
      id: id,
      text: data['text']?.toString() ?? '',
      senderId: data['senderId']?.toString() ?? '',
      timestamp: ts?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'senderId': senderId,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : null,
    };
  }
}
