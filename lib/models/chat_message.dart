import 'package:cloud_firestore/cloud_firestore.dart';

// --- MODEL: CHAT MESSAGE ---
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

  // --- FROM FIRESTORE DOC ---
  factory ChatMessage.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return ChatMessage.fromMap(data, id: doc.id);
  }

  // --- FROM MAP ---
  factory ChatMessage.fromMap(Map<String, dynamic> data, {String id = ''}) {
    final Timestamp? ts = data['timestamp'] as Timestamp?;
    return ChatMessage(
      id: id,
      text: data['text']?.toString() ?? '',
      senderId: data['senderId']?.toString() ?? '',
      timestamp: ts?.toDate(),
    );
  }

  // --- TO MAP ---
  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'senderId': senderId,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : null,
    };
  }
}
