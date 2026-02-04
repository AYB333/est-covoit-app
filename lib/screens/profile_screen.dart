import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/translations.dart';
import '../widgets/user_avatar.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  bool _isSaving = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameController = TextEditingController(
      text: user?.displayName ?? user?.email?.split('@').first ?? '',
    );
    _emailController = TextEditingController(
      text: user?.email ?? '',
    );
    _phoneController = TextEditingController(); // Init empty first

    // Fetch Phone Number from Firestore
    if (user != null) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((doc) {
        if (doc.exists && doc.data() != null) {
          final data = doc.data() as Map<String, dynamic>;
          if (mounted && data.containsKey('phoneNumber')) {
             setState(() {
               _phoneController.text = data['phoneNumber'];
             });
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final file = File(pickedFile.path);
      final ref = FirebaseStorage.instance.ref().child('profile_images/${user.uid}.jpg');
      
      // Upload
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final uploadTask = ref.putFile(file, metadata);
      
      final snapshot = await uploadTask.whenComplete(() => null);

      if (snapshot.state == TaskState.success) {
        // Small delay to ensure consistency
        await Future.delayed(const Duration(milliseconds: 500));
        
        final downloadUrl = await snapshot.ref.getDownloadURL();
        await user.updatePhotoURL(downloadUrl);
        await user.reload(); 

        // --- UPDATE FIRESTORE DOCUMENTS ---
        final db = FirebaseFirestore.instance;
        final batch = db.batch(); // Use batch for atomicity

        // 1. Update rides where I am the driver
        final ridesQuery = await db.collection('rides').where('driverId', isEqualTo: user.uid).get();
        for (var doc in ridesQuery.docs) {
          batch.update(doc.reference, {'driverPhotoUrl': downloadUrl});
        }

        // 2. Update bookings where I am the passenger
        final passengerBookings = await db.collection('bookings').where('passengerId', isEqualTo: user.uid).get();
        for (var doc in passengerBookings.docs) {
          batch.update(doc.reference, {'passengerPhotoUrl': downloadUrl});
        }

        // 3. Update bookings where I am the driver
        final driverBookings = await db.collection('bookings').where('driverId', isEqualTo: user.uid).get();
        for (var doc in driverBookings.docs) {
          batch.update(doc.reference, {'driverPhotoUrl': downloadUrl});
        }

        await batch.commit();
        // ----------------------------------
        
        if (mounted) {
          setState(() {}); 
          _showSnackBar("Photo de profil mise à jour et synchronisée !", Colors.green);
        }
      } else {
         throw Exception("Statut upload incorrect: ${snapshot.state}");
      }
    } catch (e) {
      // Check for specific firebase error
      String errorMsg = "Erreur upload: $e";
      if (e.toString().contains("object-not-found")) {
        errorMsg = "Erreur: Le fichier n'a pas été créé. Vérifiez vos Règles de Stockage Firebase.";
      } else if (e.toString().contains("unauthorized")) {
         errorMsg = "Erreur: Permission refusée. Vérifiez vos Règles de Stockage.";
      }
      _showSnackBar(errorMsg, Colors.redAccent);
    } finally {
       if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      _showSnackBar('Le nom ne peut pas être vide', Colors.redAccent);
      return;
    }

    setState(() => _isSaving = true);
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Update display name
        await user.updateDisplayName(newName);
        await user.reload();
        
        // Save Phone Number to Firestore
        final phone = _phoneController.text.trim();
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'phoneNumber': phone,
        }, SetOptions(merge: true));
      }

      if (!context.mounted) return;
      _showSnackBar(Translations.getText(context, 'profile_updated'), Colors.green);
    } catch (e) {
      _showSnackBar('Erreur: ${e.toString()}', Colors.redAccent);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showChangePasswordDialog() {
    final TextEditingController passwordController = TextEditingController();
    bool _obscurePassword = true;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(Translations.getText(context, 'change_password')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: Translations.getText(context, 'password_field'),
                      hintText: 'Min 6 caractères',
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(Translations.getText(context, 'cancel_btn')),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newPassword = passwordController.text.trim();
                    if (newPassword.length < 6) {
                      _showSnackBar('Le mot de passe doit contenir au moins 6 caractères', Colors.redAccent);
                      return;
                    }
                    try {
                      await FirebaseAuth.instance.currentUser?.updatePassword(newPassword);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      _showSnackBar('Mot de passe changé', Colors.green);
                    } on FirebaseAuthException catch (e) {
                      if (e.code == 'requires-recent-login') {
                        _showSnackBar('Veuillez vous reconnecter pour changer le mot de passe', Colors.redAccent);
                      } else if (e.code == 'weak-password') {
                        _showSnackBar('Mot de passe trop faible', Colors.redAccent);
                      } else {
                        _showSnackBar('Erreur: ${e.message ?? e.code}', Colors.redAccent);
                      }
                    } catch (e) {
                      _showSnackBar('Erreur: ${e.toString()}', Colors.redAccent);
                    }
                  },
                  child: Text(Translations.getText(context, 'save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(Translations.getText(context, 'profile')),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar Section with Camera Badge
            // Avatar Section with Camera Badge
            Center(
              child: Stack(
                children: [
                   UserAvatar(
                     userName: _nameController.text,
                     imageUrl: FirebaseAuth.instance.currentUser?.photoURL,
                     radius: 60,
                     backgroundColor: scheme.primary.withOpacity(0.2),
                     textColor: scheme.primary,
                     fontSize: 40,
                   ),
                   Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _isUploadingImage ? null : _pickAndUploadImage,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.primary,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: _isUploadingImage 
                          ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Name Field
            Text(
              Translations.getText(context, 'name_field'),
              style: textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 24),

            // Email Field (Read-only)
            Text(
              Translations.getText(context, 'email_field'),
              style: textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              readOnly: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 24),

            // Phone Field
            const Text(
              "Téléphone",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: "06 12 34 56 78",
                prefixIcon: const Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 30),

            // Change Password Tile (Modern)
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: scheme.primary.withOpacity(0.3),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                leading: Icon(
                  Icons.lock,
                  color: scheme.primary,
                ),
                title: Text(
                  Translations.getText(context, 'change_password'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: scheme.primary,
                ),
                onTap: _showChangePasswordDialog,
              ),
            ),
            const SizedBox(height: 40),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveName,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        Translations.getText(context, 'save'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
