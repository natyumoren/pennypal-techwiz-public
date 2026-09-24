import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Device (system tray) notifications on Android and iOS. On the Web the
/// app relies on in-app notifications and snack bars only.
class LocalNotifier {
  LocalNotifier._();
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static int _id = 0;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> init() async {
    if (!_supported || _ready) return;
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings);
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  static Future<void> show(String title, String body) async {
    if (!_ready) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'pennypal_alerts',
        'Budget & savings alerts',
        channelDescription: 'Spending limit and savings goal notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    try {
      await _plugin.show(_id++, title, body, details);
    } catch (e) {
      debugPrint('Could not show notification: $e');
    }
  }
}
