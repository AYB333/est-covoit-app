import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'package:est_covoit/home_screen.dart'; // This is now DashboardScreen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const EstCovoitApp());
}

class EstCovoitApp extends StatelessWidget {
  const EstCovoitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EST-Covoit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
