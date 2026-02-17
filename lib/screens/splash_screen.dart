import 'package:flutter/material.dart';

// --- WIDGET: SPLASH GATE (DELAY) ---
class SplashGate extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const SplashGate({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 2500),
  });

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  // --- STATE: SHOW SPLASH ---
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.duration, () {
      if (!mounted) return;
      setState(() => _showSplash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // --- SWITCH BETWEEN SPLASH AND CHILD ---
    if (_showSplash) {
      return const SplashScreen();
    }
    return widget.child;
  }
}

// --- SCREEN: SPLASH IMAGE ---
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SizedBox.expand(
        child: Image(
          image: AssetImage('assets/splash.png'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
