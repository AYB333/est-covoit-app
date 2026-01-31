import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ChangeNotifier {
  String _currentLanguage = 'fr'; // Default to French
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  String get currentLanguage => _currentLanguage;
  bool get isInitialized => _isInitialized;

  LanguageService() {
    _initLanguage();
  }

  Future<void> _initLanguage() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _currentLanguage = _prefs.getString('currentLanguage') ?? 'fr';
    } catch (e) {
      _currentLanguage = 'fr';
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    if (_currentLanguage != languageCode) {
      _currentLanguage = languageCode;
      try {
        await _prefs.setString('currentLanguage', languageCode);
      } catch (e) {
        // Handle error silently
      }
      notifyListeners();
    }
  }

  Locale getLocale() {
    switch (_currentLanguage) {
      case 'en':
        return const Locale('en');
      case 'darija':
        return const Locale('fr'); // Force LTR for Latin-script Darija
      case 'fr':
      default:
        return const Locale('fr');
    }
  }
}
