import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_message.dart';

// --- REPO: CHAT MESSAGES ---
class ChatRepository {
  final FirebaseFirestore _db;

  ChatRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  // --- STREAM: MESSAGES ---
  Stream<List<ChatMessage>> streamMessages(String bookingId) {
    return _db
        .collection('bookings')
        .doc(bookingId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(ChatMessage.fromDoc).toList());
  }

  // --- SEND MESSAGE ---
  Future<void> sendMessage(String bookingId, ChatMessage message) async {
    final data = message.toMap();
    data['timestamp'] = FieldValue.serverTimestamp();
    await _db.collection('bookings').doc(bookingId).collection('messages').add(data);
  }

  // --- DELETE MESSAGE ---
  Future<void> deleteMessage(String bookingId, String messageId) async {
    await _db.collection('bookings').doc(bookingId).collection('messages').doc(messageId).delete();
  }
}
