import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 로컬 시스템 알림 (동반자 '눈치주기' 수신 표시용).
class LocalNotifications {
  LocalNotifications._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'nudge';
  static const _channelName = '훈련 응원';

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
    );
    // Android 8+ 알림 채널 생성.
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: '동반자가 보낸 훈련 응원 알림',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> show({required String title, required String body}) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: '동반자가 보낸 훈련 응원 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
