import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import '../firebase_options.dart';
import '../main.dart';

const _notificationChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'Important notifications',
  description: 'Notifications about inventory and sales.',
  importance: Importance.high,
);

/// Runs in a separate isolate for data messages received in the background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Handling background message: ${message.messageId}');
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // Initialize notification service
  Future<void> initialize() async {
    if (!isFirebaseInitialized) {
      debugPrint('Skipping notification service initialization because Firebase is not ready');
      return;
    }

    try {
      await _initializeLocalNotifications();
      await _requestPermissions();
      
      // Get FCM token
      await _getFCMToken();
      
      final messaging = FirebaseMessaging.instance;

      // Configure foreground message handling
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Configure background message handling
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
      
      // Store a refreshed token as soon as Firebase rotates it.
      messaging.onTokenRefresh.listen(_saveFCMToken);

      // At first launch there may be no signed-in user, so save the existing
      // token as soon as the user signs in instead of waiting for a refresh.
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) _getFCMToken();
      });
      
      // Check for initial message if app was opened from notification
      final RemoteMessage? initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleBackgroundMessage(initialMessage);
      }
    } catch (e) {
      debugPrint('Notification service initialization failed: $e');
    }
  }
  
  // Request notification permissions
  Future<void> _requestPermissions() async {
    final messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    
    debugPrint('Notification permission granted: ${settings.authorizationStatus}');

    // Android 13+ also requires a runtime permission for local notifications.
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }
  
  // Initialize local notifications for foreground messages
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );
    
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_notificationChannel);
  }
  
  // Get FCM token
  Future<void> _getFCMToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      String? token = await messaging.getToken();
      debugPrint('FCM Token: $token');
      
      // You can send this token to your backend server
      // to send targeted notifications to this device
      if (token != null) {
        // Save token to Firestore or send to backend
        await _saveFCMToken(token);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }
  
  // Save FCM token to Firestore
  Future<void> _saveFCMToken(String token) async {
    try {
      if (isFirebaseInitialized && FirebaseAuth.instance.currentUser != null) {
        final user = FirebaseAuth.instance.currentUser;
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .set({
          'fcmToken': token,
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        debugPrint('FCM token saved to Firestore');
      }
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }
  
  // Handle foreground messages (when app is open)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Received foreground message: ${message.notification?.title}');
    
    // Show local notification for foreground messages, including data-only FCM
    // messages which do not contain a `notification` payload.
    RemoteNotification? notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'New notification';
    final body = notification?.body ?? message.data['body'] ?? '';
    await _localNotifications.show(
      message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _notificationChannel.id,
          _notificationChannel.name,
          channelDescription: _notificationChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
    
    // Also add to in-app notifications
    final context = navigatorKey.currentContext;
    if (context != null) {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      appState.addNotification(
        title,
        body,
        category: message.data['category'] ?? 'general',
        payload: message.data,
      );
    }
  }
  
  // Handle background messages (when app is in background but not terminated)
  void _handleBackgroundMessage(RemoteMessage message) {
    debugPrint('Received background message: ${message.notification?.title}');
    
    // Navigate to appropriate screen based on notification data
    // You can add navigation logic here
  }
  
  // Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
    }
  }
  
  // Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic: $e');
    }
  }
  
  // Send local notification (for testing or in-app notifications)
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel',
      'Important notifications',
      channelDescription: 'Notifications about inventory and sales.',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();
    
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }
}
