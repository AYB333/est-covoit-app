import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String _displayName;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _displayName = user?.displayName ?? user?.email?.split('@').first ?? 'Utilisateur';
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      _showSnackBar('Erreur lors de la déconnexion: $e', Colors.redAccent);
    }
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

  void _showEditNameDialog() {
    final TextEditingController nameController = TextEditingController(text: _displayName);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Modifier le nom'),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Nouveau nom',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isEmpty) {
                  _showSnackBar('Le nom ne peut pas être vide', Colors.redAccent);
                  return;
                }
                try {
                  await FirebaseAuth.instance.currentUser?.updateDisplayName(newName);
                  await FirebaseAuth.instance.currentUser?.reload();
                  setState(() => _displayName = newName);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _showSnackBar('Nom mis à jour', Colors.green);
                } catch (e) {
                  _showSnackBar('Erreur: ${e.toString()}', Colors.redAccent);
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  void _showChangePasswordDialog() {
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Changer le mot de passe'),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Nouveau mot de passe',
              hintText: 'Min 6 caractères',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
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
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email ?? 'Email non disponible';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Profil'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue[200],
                ),
                child: Icon(Icons.person, size: 60, color: Colors.blue[800]),
              ),
              const SizedBox(height: 25),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _displayName,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: _showEditNameDialog,
                    tooltip: 'Modifier le nom',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Text(userEmail, style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 30),

              SizedBox(
                width: 250,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _showChangePasswordDialog,
                  icon: const Icon(Icons.lock),
                  label: const Text('Changer le mot de passe'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                ),
              ),
              const SizedBox(height: 60),

              SizedBox(
                width: 200,
                height: 55,
                child: ElevatedButton(
                  onPressed: () => _logout(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  child: const Text('Se déconnecter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
