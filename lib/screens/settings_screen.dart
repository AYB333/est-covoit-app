import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'profile_screen.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';
import '../config/translations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

// --- SCREEN: SETTINGS ---
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // --- STATE: NOTIFICATIONS ---
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    // --- LOAD PREFS ---
    _loadPreferences();
  }

  // --- READ PREFERENCES ---
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  // --- TOGGLE NOTIFICATIONS ---
  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (value) {
      // User wants to enable, ask for permission
      bool? granted = await NotificationService().requestPermissions();
      if (granted == true) {
        setState(() => _notificationsEnabled = true);
        await prefs.setBool('notifications_enabled', true);
      } else {
        // Permission denied
        setState(() => _notificationsEnabled = false);
        await prefs.setBool('notifications_enabled', false);
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(Translations.getText(context, 'notification_permission_denied'))),
           );
        }
      }
    } else {
      // User disabling
      setState(() => _notificationsEnabled = false);
      await prefs.setBool('notifications_enabled', false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final languageService = context.watch<LanguageService>();
    final scheme = Theme.of(context).colorScheme;
    final isDarkMode = themeService.isDarkMode;
    final currentLanguage = languageService.currentLanguage;
    final languageNames = Translations.getLanguageNames();

    return Scaffold(
      // --- APPBAR ---
      appBar: AppBar(
        title: Text(Translations.getText(context, 'settings_title')),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // --- BODY: SECTIONS ---
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- SECTION: APPEARANCE ---
          _buildSectionHeader(Translations.getText(context, 'appearance_section')),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: SwitchListTile(
              title: Text(Translations.getText(context, 'dark_mode')),
              subtitle: Text(
                Translations.getText(context, isDarkMode ? 'enabled' : 'disabled'),
              ),
              value: isDarkMode,
              onChanged: (_) => themeService.toggleTheme(),
              secondary: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
            ),
          ),
          const SizedBox(height: 24),

          // --- SECTION: GENERAL ---
          _buildSectionHeader(Translations.getText(context, 'general_section')),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(Translations.getText(context, 'notifications')),
                  subtitle: Text(
                    Translations.getText(context, _notificationsEnabled ? 'enabled' : 'disabled'),
                  ),
                  value: _notificationsEnabled,
                  onChanged: _toggleNotifications,
                  secondary: const Icon(Icons.notifications),
                ),
                Divider(
                  color: Colors.grey.withValues(alpha: 0.3),
                  height: 1,
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.language, color: scheme.primary),
                          const SizedBox(width: 12),
                          Text(
                            Translations.getText(context, 'language'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButton<String>(
                        value: currentLanguage,
                        isExpanded: true,
                        underline: Container(
                          height: 2,
                          color: scheme.primary,
                        ),
                        items: [
                          for (var entry in languageNames.entries)
                            DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                        ],
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            languageService.setLanguage(newValue);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- SECTION: PROFILE ---
          _buildSectionHeader(Translations.getText(context, 'profile_section')),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: ListTile(
              leading: Icon(Icons.edit, color: scheme.primary),
              title: Text(
                Translations.getText(context, 'edit_profile'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                ).then((_) => setState(() {})); // Refresh on return
              },
            ),
          ),
          const SizedBox(height: 24),

          // --- SECTION: SUPPORT ---
          _buildSectionHeader(Translations.getText(context, 'support_section')),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.headset_mic, color: scheme.primary),
                  title: Text(
                    Translations.getText(context, 'contact_support'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(Translations.getText(context, 'support_contact_message')),
                        backgroundColor: scheme.primary,
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  },
                ),
                Divider(
                  color: Colors.grey.withValues(alpha: 0.3),
                  height: 1,
                ),
                ListTile(
                  leading: Icon(Icons.info, color: scheme.primary),
                  title: Text(
                    Translations.getText(context, 'about'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'EST-Covoit',
                      applicationVersion: '1.0.0',
                      applicationLegalese: Translations.getText(context, 'app_legalese'),
                      children: [
                        Text(Translations.getText(context, 'about_description')),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- INFO ---
          Center(
            child: Text(
              'Version 1.0.0',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- SECTION HEADER WIDGET ---
  Widget _buildSectionHeader(String title) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: scheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
