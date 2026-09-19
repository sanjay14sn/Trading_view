import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(settings: initializationSettings);
  }

  static Future<void> showSignalNotification(Map<String, dynamic> signalData) async {
    final symbol = signalData['symbol'] ?? signalData['rawSymbol'] ?? 'NIFTY';
    final action = (signalData['action'] ?? 'BUY').toString().toUpperCase();
    final price = signalData['price'] ?? 0;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'tradingview_signals_channel',
      'TradingView Signal Alerts',
      channelDescription: 'High-priority trading signals and order execution alerts',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'New Trading Signal',
      playSound: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'alert.wav',
      ),
    );

    await _notificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '🚨 $action SIGNAL: $symbol',
      body: 'Target Price: ₹$price • Executing Zerodha Market Order',
      notificationDetails: notificationDetails,
    );
  }
}
