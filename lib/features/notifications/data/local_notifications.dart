import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Displays notifications while the app is in the foreground (FCM does not
/// show them itself there) and reports taps. Android channel `messages` is
/// created here and referenced by the Cloud Function payload.
class LocalNotifications {
  static const channelId = 'messages';
  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<String>.broadcast();
  String? launchConversationId;

  Stream<String> get taps => _taps.stream;

  Future<void> init() async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is requested contextually via firebase_messaging.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        final id = r.payload;
        if (id != null && id.isNotEmpty) _taps.add(id);
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            'Messages',
            description: 'New message notifications',
            importance: Importance.high,
          ),
        );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      launchConversationId = launch?.notificationResponse?.payload;
    }
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String conversationId,
  }) => _plugin.show(
    id,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        'Messages',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: false,
      ),
    ),
    payload: conversationId,
  );
}

final localNotificationsProvider = Provider<LocalNotifications>(
  (_) => throw UnimplementedError('Overridden in bootstrap'),
);
