import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  }
}
