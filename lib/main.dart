import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'login_screen.dart';
import 'theme_service.dart';
import 'language_service.dart';
import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService().initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => LanguageService()),
      ],
      child: const EstCovoitApp(),
    ),
  );
}

class EstCovoitApp extends StatelessWidget {
  const EstCovoitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeService, LanguageService>(
      builder: (context, themeService, languageService, _) {
        return MaterialApp(
          title: 'EST-Covoit',
          debugShowCheckedModeBanner: false,
          theme: themeService.getLightTheme(),
          darkTheme: themeService.getDarkTheme(),
          themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          locale: languageService.getLocale(),
          supportedLocales: const [
            Locale('fr'),
            Locale('en'),
            Locale('ar'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const LoginScreen(),
        );
      },
    );
  }
}
