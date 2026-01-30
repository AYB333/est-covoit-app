import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'language_service.dart';

class Translations {
  static const Map<String, Map<String, String>> _translations = {
    'fr': {
      'home_title': 'Bonjour',
      'driver_card': 'Je suis Conducteur',
      'driver_subtitle': 'Publier un trajet, partager les frais.',
      'passenger_card': 'Je suis Passager',
      'passenger_subtitle': 'Trouver un trajet vers l\'EST.',
      'settings_title': 'Paramètres',
      'dark_mode': 'Mode Sombre',
      'language': 'Langue',
      'logout': 'Se déconnecter',
      'logout_confirm': 'Voulez-vous vraiment se déconnecter ?',
      'logout_btn': 'Déconnecter',
      'cancel_btn': 'Annuler',
      'search_btn': 'Chercher',
      'edit_profile': 'Modifier mon profil',
      'notifications': 'Notifications',
      'contact_support': 'Contacter le support',
      'about': 'À propos',
      'general_section': 'Général',
      'appearance_section': 'Apparence',
      'profile_section': 'Profil',
      'support_section': 'Support',
      'confirm_journey': 'Confirmer le trajet',
      'publish_journey': 'Publier le trajet',
      'available_trips': 'Trajets Disponibles',
      'no_trips': 'Aucun trajet disponible pour le moment.',
      'save': 'Enregistrer',
      'name_field': 'Nom',
      'email_field': 'Email',
      'phone_field': 'Téléphone',
      'change_password': 'Changer mot de passe',
      'success': 'Succès',
      'profile': 'Mon Profil',
      'profile_updated': 'Profil mis à jour',
      'password_field': 'Mot de passe',
    },
    'en': {
      'home_title': 'Hello',
      'driver_card': 'I am a Driver',
      'driver_subtitle': 'Publish a trip, share costs.',
      'passenger_card': 'I am a Passenger',
      'passenger_subtitle': 'Find a trip to EST.',
      'settings_title': 'Settings',
      'dark_mode': 'Dark Mode',
      'language': 'Language',
      'logout': 'Logout',
      'logout_confirm': 'Are you sure you want to logout?',
      'logout_btn': 'Logout',
      'cancel_btn': 'Cancel',
      'search_btn': 'Search',
      'edit_profile': 'Edit my profile',
      'notifications': 'Notifications',
      'contact_support': 'Contact Support',
      'about': 'About',
      'general_section': 'General',
      'appearance_section': 'Appearance',
      'profile_section': 'Profile',
      'support_section': 'Support',
      'confirm_journey': 'Confirm Journey',
      'publish_journey': 'Publish Journey',
      'available_trips': 'Available Trips',
      'no_trips': 'No trips available at the moment.',
      'save': 'Save',
      'name_field': 'Name',
      'email_field': 'Email',
      'phone_field': 'Phone',
      'change_password': 'Change Password',
      'success': 'Success',
      'profile': 'My Profile',
      'profile_updated': 'Profile Updated',
      'password_field': 'Password',
    },
    'darija': {
      'home_title': 'Ahlan',
      'driver_card': 'Ana Chiffour',
      'driver_subtitle': 'Shuft un trajet, qessem l-tmen.',
      'passenger_card': 'Ana Rakib',
      'passenger_subtitle': 'Hani tajet l-EST.',
      'settings_title': 'I3dadat',
      'dark_mode': 'Mode K7el',
      'language': 'Logha',
      'logout': 'Khrouj',
      'logout_confirm': 'Kunt tab9a memen nti khrejna?',
      'logout_btn': 'Khrouj',
      'cancel_btn': 'Skoun',
      'search_btn': '9elleb',
      'edit_profile': 'Beddel profil diyali',
      'notifications': 'Notification',
      'contact_support': 'Kellemt support',
      'about': 'Hadek lapp',
      'general_section': 'Amm',
      'appearance_section': 'Chkel',
      'profile_section': 'Profil',
      'support_section': 'Support',
      'confirm_journey': 'Oked tajet',
      'publish_journey': 'Nshur tajet',
      'available_trips': 'Tajjat Dialak',
      'no_trips': 'Wakha tajet knoun hna.',
      'save': 'Sejjel',
      'name_field': 'Smiyak',
      'email_field': 'Email',
      'phone_field': 'Telefon',
      'change_password': 'Beddel sser',
      'success': 'Zewin',
      'profile': 'Profil diyali',
      'profile_updated': 'Profil tbeddel',
      'password_field': 'Sser',
    },
  };

  static String getText(BuildContext context, String key) {
    final languageCode = _getLanguageCode(context);
    return _translations[languageCode]?[key] ?? 
           _translations['fr']?[key] ?? 
           key;
  }

  static String _getLanguageCode(BuildContext context) {
    try {
      final languageService = context.watch<LanguageService>();
      return languageService.currentLanguage;
    } catch (e) {
      // Fallback if provider is not available
      return 'fr';
    }
  }

  static List<String> getSupportedLanguages() {
    return _translations.keys.toList();
  }

  static Map<String, String> getLanguageNames() {
    return {
      'fr': 'Français',
      'en': 'English',
      'darija': 'Darija',
    };
  }
}
