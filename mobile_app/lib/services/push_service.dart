import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init in background warning: $e');
  }

  debugPrint('📱 [BACKGROUND/COLD PUSH] Received message: ${message.messageId}');
  final data = message.data;

  // Show high priority local notification even when app is killed/closed
  if (data.isNotEmpty) {
    await LocalNotificationService.init();
    await LocalNotificationService.showSignalNotification(data);
  }
}

class PushService {
  static String? _deviceToken;
  static String? get deviceToken => _deviceToken;

  static Function(Map<String, dynamic> data)? onSignalNotificationOpened;

  static Future<void> init(String backendUrl) async {
    try {
      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp();
        } catch (_) {
          // If google-services.json is not placed in android/app/, check for dotenv fallback credentials
          final apiKey = dotenv.env['FIREBASE_API_KEY'];
          final appId = dotenv.env['FIREBASE_APP_ID'];
          final messagingSenderId = dotenv.env['FIREBASE_MESSAGING_SENDER_ID'];
          final projectId = dotenv.env['FIREBASE_PROJECT_ID'];

          if (apiKey != null && appId != null && messagingSenderId != null && projectId != null) {
            await Firebase.initializeApp(
              options: FirebaseOptions(
                apiKey: apiKey,
                appId: appId,
                messagingSenderId: messagingSenderId,
                projectId: projectId,
              ),
            );
          } else {
            rethrow;
          }
        }
      }

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // Request notification permissions
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
      );

      debugPrint('🔔 FCM User Permission status: ${settings.authorizationStatus}');

      // Get FCM token
      _deviceToken = await messaging.getToken();
      if (_deviceToken != null) {
        debugPrint('🔑 FCM Push Token: $_deviceToken');
        await registerTokenWithBackend(backendUrl, _deviceToken!);
      }

      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) {
        _deviceToken = newToken;
        registerTokenWithBackend(backendUrl, newToken);
      });

      // Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📱 [FOREGROUND PUSH] Received: ${message.data}');
        if (message.data.isNotEmpty) {
          LocalNotificationService.showSignalNotification(message.data);
          onSignalNotificationOpened?.call(message.data);
        }
      });

      // Handle notification opened when app was in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('📱 [PUSH OPENED] App opened via push notification: ${message.data}');
        if (message.data.isNotEmpty) {
          onSignalNotificationOpened?.call(message.data);
        }
      });

      // Check if launched from a terminated/cold state via notification tap
      RemoteMessage? initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null && initialMessage.data.isNotEmpty) {
        debugPrint('🚀 [COLD LAUNCH PUSH] Launched app from cold state via push notification');
        onSignalNotificationOpened?.call(initialMessage.data);
      }
    } catch (e) {
      debugPrint('⚠️ PushService init warning (Firebase configuration pending or mock environment): $e');
    }
  }

  static Future<void> registerTokenWithBackend(String backendUrl, String token) async {
    try {
      String cleanUrl = backendUrl.trim();
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }
      final uri = Uri.parse('$cleanUrl/api/push-token');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'platform': kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android'),
          'deviceId': Platform.operatingSystem,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        debugPrint('✅ FCM device token successfully registered on backend');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to send push token to backend: $e');
    }
  }
}
