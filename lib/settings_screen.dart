import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'profile_screen.dart';
import 'theme_service.dart';
import 'language_service.dart';
import 'translations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final languageService = context.watch<LanguageService>();
    final isDarkMode = themeService.isDarkMode;
    final currentLanguage = languageService.currentLanguage;
    final languageNames = Translations.getLanguageNames();

    return Scaffold(
      appBar: AppBar(
        title: Text(Translations.getText(context, 'settings_title')),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- APPARENCE SECTION ---
          _buildSectionHeader(Translations.getText(context, 'appearance_section')),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: SwitchListTile(
              title: Text(Translations.getText(context, 'dark_mode')),
              subtitle: Text(isDarkMode ? 'Activé' : 'Désactivé'),
              value: isDarkMode,
              onChanged: (_) => themeService.toggleTheme(),
              secondary: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
            ),
          ),
          const SizedBox(height: 24),

          // --- GÉNÉRAL SECTION ---
          _buildSectionHeader(Translations.getText(context, 'general_section')),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(Translations.getText(context, 'notifications')),
                  subtitle: Text(_notificationsEnabled ? 'Activées' : 'Désactivées'),
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() => _notificationsEnabled = value);
                  },
                  secondary: const Icon(Icons.notifications),
                ),
                Divider(
                  color: Colors.grey.withOpacity(0.3),
                  height: 1,
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.language, color: Colors.blue),
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
                          color: Colors.blue[800],
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

          // --- PROFIL SECTION ---
          _buildSectionHeader(Translations.getText(context, 'profile_section')),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
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

          // --- SUPPORT SECTION ---
          _buildSectionHeader(Translations.getText(context, 'support_section')),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.headset_mic, color: Colors.blue),
                  title: Text(
                    Translations.getText(context, 'contact_support'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Support: Envoyez un email à aitomghar26@gmail.com'),
                        backgroundColor: Colors.blue,
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  },
                ),
                Divider(
                  color: Colors.grey.withOpacity(0.3),
                  height: 1,
                ),
                ListTile(
                  leading: const Icon(Icons.info, color: Colors.blue),
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
                      applicationLegalese: '© 2026 EST-Covoit. Tous droits réservés.',
                      children: [
                        const Text(
                          'EST-Covoit est une application de covoiturage conçue pour '
                          'faciliter les trajets entre les étudiants et salariés. '
                          'Partagez vos trajets, économisez, et contribuez à un transport '
                          'plus écologique.',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- INFO texte ---
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

  // Helper widget to create section headers
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.blue[800],
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
