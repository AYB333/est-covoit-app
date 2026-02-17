import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../repositories/user_repository.dart';

// --- SERVICE: AUTH ---
class AuthService {
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final UserRepository _users;

  AuthService({
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    UserRepository? users,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _users = users ?? UserRepository();

  // --- SIGN IN ---
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // --- SIGN OUT ---
  Future<void> signOut() {
    return _auth.signOut();
  }

  // --- SIGN UP (AUTH + STORAGE + FIRESTORE) ---
  Future<UserCredential> signUp({
    required String name,
    required String email,
    required String password,
    required String phoneNumber,
    File? profileImage,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    String? photoUrl;
    if (profileImage != null) {
      final ref = _storage.ref().child('profile_images/${credential.user!.uid}.jpg');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final uploadTask = ref.putFile(profileImage, metadata);
      final snapshot = await uploadTask.whenComplete(() => null);
      if (snapshot.state == TaskState.success) {
        await Future.delayed(const Duration(milliseconds: 500));
        photoUrl = await snapshot.ref.getDownloadURL();
      }
    }

    await credential.user?.updateProfile(
      displayName: name,
      photoURL: photoUrl,
    );
    await credential.user?.reload();

    await _users.setPhoneNumber(credential.user!.uid, phoneNumber);
    return credential;
  }
}
