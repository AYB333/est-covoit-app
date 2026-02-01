import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Android Init
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); 

    // iOS Init (basic)
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );

    // --- NEW: FCM Setup ---
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    
    // Request Permission (Alert + Sound)
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    // Get Token & Save
    String? token = await messaging.getToken();
    if (token != null) _saveToken(token);

    // Listen for Token Refresh
    messaging.onTokenRefresh.listen(_saveToken);

    // Foreground Message Handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
       print('Got a message whilst in the foreground!');
       if (message.notification != null) {
         _showNotification(
           id: message.hashCode,
           title: message.notification!.title ?? 'Notification',
           body: message.notification!.body ?? '',
         );
       }
    });
    
    // Background Handler is set in main.dart usually, but good to know mechanism exists
  }
  
  Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    }
  }

  Future<bool?> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      return await androidImplementation.requestNotificationsPermission();
    }
    return false;
  }

  // Call this when the user logs in or app starts
  void startListening() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('notifications')
        .where('receiverId', isEqualTo: user.uid)
        .where('read', isEqualTo: false)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          
          // Show the notification
          _showNotification(
            id: change.doc.hashCode,
            title: data['title'] ?? 'EST Covoit',
            body: data['body'] ?? '',
          );
          
          // Mark as read immediately so it doesn't show again on restart
          change.doc.reference.update({'read': true});
        }
      }
    });
  }

  Future<void> _showNotification({required int id, required String title, required String body}) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('notifications_enabled') == false) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'est_covoit_channel_id',
      'Notifications EST Covoit',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  // --- STATIC HELPERS TO SEND NOTIFICATIONS ---

  static Future<void> sendNotification({
    required String receiverId,
    required String title,
    required String body,
    required String type, // 'booking', 'chat', 'status'
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    // Don't notify self
    if (user != null && user.uid == receiverId) return;

    await FirebaseFirestore.instance.collection('notifications').add({
      'receiverId': receiverId,
      'senderId': user?.uid,
      'title': title,
      'body': body,
      'type': type,
      'read': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
    
    // --- SEND PUSH NOTIFICATION (FCM) ---
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(receiverId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data() as Map<String, dynamic>;
        final String? fcmToken = data['fcmToken'];
        
        if (fcmToken != null && fcmToken.isNotEmpty) {
           await _sendPushNotification(
             token: fcmToken,
             title: title,
             body: body,
             type: type,
           );
        }
      }
    } catch (e) {
      print("Error sending push: $e");
    }
  }

  static Future<void> _sendPushNotification({
    required String token, 
    required String title, 
    required String body,
    required String type,
  }) async {
    try {
      // 1. Load Service Account JSON
      final jsonString = await rootBundle.loadString('assets/service_account.json');
      final serviceAccount = json.decode(jsonString);
      final String projectId = serviceAccount['project_id'];

      // 2. Get Access Token scope
      final accountCredentials = ServiceAccountCredentials.fromJson(serviceAccount);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      
      final client = await clientViaServiceAccount(accountCredentials, scopes);
      
      // 3. Send Request
      final url = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';
      
      final notificationData = {
        'message': {
          'token': token,
          'notification': {
            'title': title,
            'body': body,
          },
          'data': {
            'type': type,
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          }
        }
      };

      final response = await client.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(notificationData),
      );

      print("FCM Response: ${response.statusCode} ${response.body}");
      client.close();
      
    } catch (e) {
      print("Failed to send FCM: $e");
    }
  }
}
