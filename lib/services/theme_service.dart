import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_theme.dart';

// --- SERVICE: THEME (LIGHT/DARK) ---
class ThemeService extends ChangeNotifier {
  bool _isDarkMode = false;
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  bool get isDarkMode => _isDarkMode;
  bool get isInitialized => _isInitialized;

  // --- INIT ---
  ThemeService() {
    _initTheme();
  }

  // --- LOAD SAVED THEME ---
  Future<void> _initTheme() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _isDarkMode = _prefs.getBool('isDarkMode') ?? false;
    } catch (e) {
      _isDarkMode = false;
    }
    _isInitialized = true;
    notifyListeners();
  }

  // --- TOGGLE THEME ---
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _prefs.setBool('isDarkMode', _isDarkMode);
    notifyListeners();
  }

  // --- THEMES ---
  ThemeData getLightTheme() {
    return AppTheme.light();
  }

  ThemeData getDarkTheme() {
    return AppTheme.dark();
  }
}
