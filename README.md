# est_covoit

Flutter app de covoiturage avec authentification et gestion de trajets.
Objectif: code organise, clair et facile a maintenir sans changer le comportement.

## Stack
- Flutter / Dart
- Firebase (Auth, Firestore, Messaging)
- Provider (theme / language)

## Structure du projet
- `lib/config/` : theme + traductions
- `lib/screens/` : ecrans principaux
- `lib/services/` : services et logique (Firebase, notifications, etc.)
- `lib/widgets/` : widgets reutilisables
- `lib/main.dart` : point d'entree

### Home (module principal)
- `lib/screens/home_screen.dart` : orchestrateur (tabs + bottom nav)
- `lib/widgets/home/home_tab_view.dart` : contenu onglet Home
- `lib/widgets/home/home_header.dart` : header (avatar + bonjour + logout)
- `lib/widgets/home/home_role_card.dart` : cartes Conducteur / Passager
- `lib/widgets/home/my_rides_tab.dart` : onglet Mes trajets
- `lib/widgets/home/driver_rides_list.dart` : liste rides conducteur
- `lib/widgets/home/passenger_bookings_list.dart` : liste bookings passager

## Ecrans principaux
- `lib/screens/login_screen.dart`
- `lib/screens/signup_screen.dart`
- `lib/screens/splash_screen.dart`
- `lib/screens/settings_screen.dart`
- `lib/screens/profile_screen.dart`
- `lib/screens/add_ride_screen.dart`
- `lib/screens/find_ride_screen.dart`
- `lib/screens/ride_details_screen.dart`
- `lib/screens/ride_map_viewer.dart`
- `lib/screens/chat_screen.dart`

## Services
- `lib/services/notification_service.dart` : notifications locales + FCM
- `lib/services/booking_service.dart` : creation / gestion reservations
- `lib/services/theme_service.dart` : theme (dark / light)
- `lib/services/language_service.dart` : langue

## Config UI
- `lib/config/app_theme.dart`
- `lib/config/translations.dart`

## Firebase
Collections principales:
- `rides`
- `bookings`

## Commandes utiles
- Analyse: `flutter analyze`
- Run: `flutter run`

## Notes
- Organisation only (pas de changement de logique)
- Design conserve
- Imports a jour apres reorganisation
