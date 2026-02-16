import 'package:cloud_firestore/cloud_firestore.dart';

class SafetyRepository {
  final FirebaseFirestore _db;

  SafetyRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  String _blockDocId(String blockerId, String blockedUserId) => '${blockerId}_$blockedUserId';

  Stream<Set<String>> streamBlockedUserIds(String blockerId) {
    return _db
        .collection('user_blocks')
        .where('blockerId', isEqualTo: blockerId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.data()['blockedUserId']?.toString() ?? '').where((id) => id.isNotEmpty).toSet());
  }

  Future<bool> isBlocked({
    required String blockerId,
    required String blockedUserId,
  }) async {
    final doc = await _db.collection('user_blocks').doc(_blockDocId(blockerId, blockedUserId)).get();
    return doc.exists;
  }

  Future<void> blockUser({
    required String blockerId,
    required String blockedUserId,
  }) async {
    await _db.collection('user_blocks').doc(_blockDocId(blockerId, blockedUserId)).set({
      'blockerId': blockerId,
      'blockedUserId': blockedUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unblockUser({
    required String blockerId,
    required String blockedUserId,
  }) async {
    await _db.collection('user_blocks').doc(_blockDocId(blockerId, blockedUserId)).delete();
  }

  Future<void> reportUser({
    required String reporterId,
    required String reportedUserId,
    required String reason,
    String? details,
    String? contextType,
    String? contextId,
  }) async {
    await _db.collection('reports').add({
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      'reason': reason,
      'details': details ?? '',
      'contextType': contextType ?? '',
      'contextId': contextId ?? '',
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
