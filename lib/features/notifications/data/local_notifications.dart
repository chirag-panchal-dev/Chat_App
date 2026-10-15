import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Displays notifications while the app is in the foreground (FCM does not
/// show them itself there) and reports taps. Android channel `messages` is
/// created here and referenced by the Cloud Function payload.
class LocalNotifications {
  static const channelId = 'messages';

  /// Same notifications without sound or vibration (quiet hours). Must match
  /// the channel id the Cloud Function uses.
  static const quietChannelId = 'messages_quiet';
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
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            quietChannelId,
            'Messages (quiet hours)',
            description: 'Silent message notifications during quiet hours',
            importance: Importance.low,
            playSound: false,
            enableVibration: false,
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
    bool quiet = false,
  }) => _plugin.show(
    id,
    title,
    body,
    NotificationDetails(
      android:
          quiet
              ? const AndroidNotificationDetails(
                quietChannelId,
                'Messages (quiet hours)',
                importance: Importance.low,
                priority: Priority.low,
                playSound: false,
                enableVibration: false,
              )
              : const AndroidNotificationDetails(
                channelId,
                'Messages',
                importance: Importance.high,
                priority: Priority.high,
              ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: !quiet,
        presentBadge: false,
      ),
    ),
    payload: conversationId,
  );
}

final localNotificationsProvider = Provider<LocalNotifications>(
  (_) => throw UnimplementedError('Overridden in bootstrap'),
);
