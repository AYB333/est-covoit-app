import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_avatar.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController(); // Hada dyal Smiya
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  File? _selectedImage;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _signUp() async {
    if (_nameController.text.isEmpty || 
        _emailController.text.isEmpty || 
        _passwordController.text.isEmpty ||
        _phoneController.text.isEmpty) {
      _showError("Veuillez remplir tous les champs.");
      return;
    }

    if (!_emailController.text.trim().endsWith("@edu.uiz.ac.ma")) {
      _showError("Veuillez utiliser votre email académique (@edu.uiz.ac.ma).");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Créer le compte b Email/Password
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Upload Image if selected
      String? photoUrl;
      if (_selectedImage != null) {
        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child('profile_images/${userCredential.user!.uid}.jpg');
          
          final metadata = SettableMetadata(contentType: 'image/jpeg');
          final uploadTask = ref.putFile(_selectedImage!, metadata);
          
          final snapshot = await uploadTask.whenComplete(() => null);

          if (snapshot.state == TaskState.success) {
             // Delay to ensure consistency
             await Future.delayed(const Duration(milliseconds: 500));
             photoUrl = await snapshot.ref.getDownloadURL();
          }
        } catch (e) {
          debugPrint("Erreur upload image au signup: $e");
          // On continue même si l'image échoue pour ne pas bloquer l'inscription
        }
      }

      // 3. SAUVEGARDER S-SMIYA & PHOTO (Update Profile)
      await userCredential.user?.updateProfile(
        displayName: _nameController.text.trim(),
        photoURL: photoUrl
      );
      await userCredential.user?.reload();

      // 4. Save phone number to Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'phoneNumber': _phoneController.text.trim(),
      }, SetOptions(merge: true));

      // 3. Afficher Message Vert u Rje3 l Login
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Expanded(child: Text("Compte créé ! Connectez-vous.", style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(20),
        ),
      );

      // Tsenna tanya u rje3 l Login
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      Navigator.pop(context); // Rje3 l Login

    } on FirebaseAuthException catch (e) {
      String message = "Erreur d'inscription.";
      if (e.code == 'email-already-in-use') {
        message = "Cet email est déjà utilisé.";
      } else if (e.code == 'weak-password') {
        message = "Mot de passe trop faible (min 6 caractères).";
      } else if (e.code == 'invalid-email') {
        message = "Email invalide.";
      }
      _showError(message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Créer un compte")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Dynamic Avatar Preview
              AnimatedBuilder(
                animation: _nameController,
                builder: (context, _) {
                  return GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        _selectedImage != null
                          ? CircleAvatar(
                              radius: 50,
                              backgroundImage: FileImage(_selectedImage!),
                              backgroundColor: Colors.grey[200],
                            )
                          : UserAvatar(
                              userName: _nameController.text.isEmpty ? "Nouveau" : _nameController.text,
                              radius: 50,
                              backgroundColor: Colors.blue[50],
                              textColor: Colors.blue,
                              fontSize: 40,
                            ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _selectedImage == null ? Icons.add : Icons.edit, 
                            color: Colors.white, 
                            size: 20
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),

              // Champs Full Name
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nom Complet',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              // Champs Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              // Champs Password
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Champs Telephone
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Téléphone',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('S\'inscrire', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}






