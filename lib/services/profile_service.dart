import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../repositories/user_repository.dart';

// --- SERVICE: PROFILE ---
class ProfileService {
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final UserRepository _users;

  ProfileService({
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    UserRepository? users,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _users = users ?? UserRepository();

  // --- UPDATE NAME + PHONE ---
  Future<void> updateDisplayNameAndPhone({
    required String name,
    required String phoneNumber,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await user.updateDisplayName(name);
    await user.reload();
    await _users.setPhoneNumber(user.uid, phoneNumber);
  }

  // --- UPDATE PROFILE PHOTO ---
  Future<void> updateProfilePhoto(File file) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ref = _storage.ref().child('profile_images/${user.uid}.jpg');
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    final uploadTask = ref.putFile(file, metadata);
    final snapshot = await uploadTask.whenComplete(() => null);
    if (snapshot.state != TaskState.success) {
      throw Exception('upload-failed');
    }

    await Future.delayed(const Duration(milliseconds: 500));
    final downloadUrl = await snapshot.ref.getDownloadURL();
    await user.updatePhotoURL(downloadUrl);
    await user.reload();

    await _users.syncProfilePhoto(user.uid, downloadUrl);
  }
}
