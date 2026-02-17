import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';

// --- REPO: NOTIFICATIONS ---
class NotificationRepository {
  final FirebaseFirestore _db;

  NotificationRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  // --- STREAM: UNREAD NOTIFS ---
  Stream<List<AppNotification>> streamUnread(String userId) {
    return _db
        .collection('notifications')
        .where('receiverId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(AppNotification.fromDoc).toList());
  }

  // --- STREAM: RAW SNAPSHOTS ---
  Stream<QuerySnapshot<Map<String, dynamic>>> streamUnreadSnapshots(String userId) {
    return _db
        .collection('notifications')
        .where('receiverId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // --- ADD NOTIFICATION ---
  Future<void> addNotification(AppNotification notification) async {
    final data = notification.toMap();
    data['timestamp'] = FieldValue.serverTimestamp();
    await _db.collection('notifications').add(data);
  }

  // --- MARK AS READ ---
  Future<void> markRead(String notificationId) async {
    await _db.collection('notifications').doc(notificationId).update({'read': true});
  }
}
