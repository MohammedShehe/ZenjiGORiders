import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/api/rider_api.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background isolates must initialize Firebase before using Firebase services.
  await Firebase.initializeApp();
  debugPrint('[Push] Background message received: ${message.messageId}');
}

class PushService {
  PushService._();
  static final instance = PushService._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _initializing = false;
  bool _tokenListenerAttached = false;

  static const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
    'zenjigo_rides',
    'ZenjiGO Rides',
    description: 'Ride status, live tracking and offers',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (_ready || _initializing || kIsWeb) return;
    _initializing = true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      await _local.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
        onDidReceiveNotificationResponse: (response) {
          debugPrint('[Push] Notification tapped. Payload: ${response.payload ?? ""}');
        },
      );

      if (Platform.isAndroid) {
        final androidLocal = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        await androidLocal?.createNotificationChannel(_androidChannel);
      }

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('[Push] Notification authorization: ${settings.authorizationStatus}');

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await messaging.getToken();
      debugPrint('[Push] FCM token available: ${token != null && token.isNotEmpty}');
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }

      if (!_tokenListenerAttached) {
        messaging.onTokenRefresh.listen((newToken) async {
          debugPrint('[Push] FCM token refreshed');
          await _registerToken(newToken);
        }, onError: (Object e) {
          debugPrint('[Push] FCM token refresh listener error: $e');
        });
        _tokenListenerAttached = true;
      }

      FirebaseMessaging.onMessage.listen((message) async {
        debugPrint('[Push] Foreground message received: ${message.messageId}');
        await _showForeground(message);
      });
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint('[Push] Notification opened app: ${message.messageId}');
      });
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[Push] App opened from notification: ${initialMessage.messageId}');
      }

      _ready = true;
    } catch (e, stack) {
      debugPrint('[Push] Initialization failed: $e');
      debugPrintStack(stackTrace: stack);
    } finally {
      _initializing = false;
    }
  }

  /// Call after successful login so the FCM token is attached to the authenticated user.
  Future<void> registerTokenNow() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[Push] Cannot register token: FCM returned an empty token');
        return;
      }
      await _registerToken(token);
    } catch (e) {
      debugPrint('[Push] Token registration after login failed: $e');
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      await RiderApi.registerFcmToken(
        token,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
      debugPrint('[Push] FCM token registered with backend');
    } catch (e) {
      // This commonly fails before login; registerTokenNow() retries after login.
      debugPrint('[Push] Backend token registration failed: $e');
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'ZenjiGO';
    final body = notification?.body ?? message.data['body'] ?? '';
    if (body.isEmpty && notification == null) {
      debugPrint('[Push] Data-only foreground message has no body; skipping local display');
      return;
    }
    await _local.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
      payload: message.data['type']?.toString(),
    );
  }
}
