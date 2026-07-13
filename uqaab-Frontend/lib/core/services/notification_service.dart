// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// class NotificationService {
//   static final NotificationService _instance = NotificationService._internal();
//   factory NotificationService() => _instance;
//   NotificationService._internal();

//   final FlutterLocalNotificationsPlugin _notifications =
//       FlutterLocalNotificationsPlugin();

//   Future<void> init() async {
//     // 🚨 FIXED: Tell the plugin to use the concrete core Android OS system drawable asset icon.
//     // This removes folder mapping lookups and stops the NullPointerException instantly!
//     const androidSettings =
//         AndroidInitializationSettings('@android:drawable/ic_dialog_alert');

//     const initSettings = InitializationSettings(android: androidSettings);
//     await _notifications.initialize(initSettings);

//     final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
//         AndroidFlutterLocalNotificationsPlugin>();

//     if (androidPlugin != null) {
//       await androidPlugin.requestNotificationsPermission();
//     }
//   }

//   Future<void> showAlertNotification({
//     required String title,
//     required String body,
//     int id = 0,
//   }) async {
//     const androidDetails = AndroidNotificationDetails(
//       'uqaab_security_channel', // Matches AndroidManifest meta-data tag perfectly
//       'Uqaab Live Alerts',
//       channelDescription: 'Real-time perimeter intrusion tracking alerts',
//       importance: Importance.max, // Required for heads-up dropdown banner card
//       priority: Priority.high, // Ensures immediate delivery processing speed
//       playSound: true,
//       enableVibration: true,
//       icon: '@android:drawable/ic_dialog_alert',
//     );
//     const details = NotificationDetails(android: androidDetails);
//     await _notifications.show(id, title, body, details);
//   }
// }

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  void Function(String alertId)? onAlertTapped;

  Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@android:drawable/ic_dialog_alert');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final alertId = response.payload;
        if (alertId != null && onAlertTapped != null) {
          onAlertTapped!(alertId);
        }
      },
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> showAlertNotification({
    required String title,
    required String body,
    required String alertId,
    int id = 0,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'uqaab_security_channel',
      'Uqaab Live Alerts',
      channelDescription: 'Real-time perimeter intrusion tracking alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@android:drawable/ic_dialog_alert',
    );
    const details = NotificationDetails(android: androidDetails);
    await _notifications.show(id, title, body, details, payload: alertId);
  }
}
