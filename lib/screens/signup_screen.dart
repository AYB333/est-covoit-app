import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/user_avatar.dart';
import '../services/auth_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  File? _selectedImage;

  Future<void> _pickImage() async {
    // Create a picker instance
    final picker = ImagePicker();
    // Pick an image from gallery (compressed to 70% quality)
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        // Save the selected image for preview and upload
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _signUp() async {
    // Basic validation: all fields required
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _phoneController.text.isEmpty) {
      _showError("Veuillez remplir tous les champs.");
      return;
    }

    // Domain check: only academic email
    if (!_emailController.text.trim().endsWith("@edu.uiz.ac.ma")) {
      _showError("Veuillez utiliser votre email academique (@edu.uiz.ac.ma).");
      return;
    }

    // Disable button and show loader
    setState(() => _isLoading = true);

    try {
      // 1) Create user in Firebase Auth
      await AuthService().signUp(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        profileImage: _selectedImage,
      );

      if (!mounted) return;
      // Success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Expanded(child: Text("Compte cree ! Connectez-vous.", style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(20),
        ),
      );

      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      // Back to login screen
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String message = "Erreur d'inscription.";
      if (e.code == 'email-already-in-use') {
        message = "Cet email est deja utilise.";
      } else if (e.code == 'weak-password') {
        message = "Mot de passe trop faible (min 6 caracteres).";
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
    // Dispose controllers to avoid memory leaks
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Decorative circle
          Positioned(
            top: -70,
            left: -40,
            child: Container(
              height: 180,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Main content area
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      IconButton(
                        // Back to previous screen
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      children: [
                        // Page title
                        Text('Creer un compte', style: textTheme.displaySmall?.copyWith(color: Colors.white)),
                        const SizedBox(height: 8),
                        // Subtitle
                        Text(
                          'Rejoignez la communaute EST',
                          style: textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.85)),
                        ),
                        const SizedBox(height: 24),
                        Card(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                // Avatar picker (image or initials)
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
                                                  radius: 46,
                                                  backgroundImage: FileImage(_selectedImage!),
                                                  backgroundColor: Colors.grey[200],
                                                )
                                              : UserAvatar(
                                                  userName: _nameController.text.isEmpty
                                                      ? "Nouveau"
                                                      : _nameController.text,
                                                  radius: 46,
                                                  backgroundColor: scheme.surfaceVariant,
                                                  textColor: scheme.primary,
                                                  fontSize: 36,
                                                ),
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: scheme.primary,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              _selectedImage == null ? Icons.add : Icons.edit,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 24),
                                // Full name
                                TextField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nom complet',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Email
                                TextField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Password with visibility toggle
                                TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Mot de passe',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Phone number
                                TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: 'Telephone',
                                    prefixIcon: Icon(Icons.phone),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    // Submit signup
                                    onPressed: _isLoading ? null : _signUp,
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                          )
                                        : const Text("S'inscrire"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
