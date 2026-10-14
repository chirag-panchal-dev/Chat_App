import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failure.dart';
import '../../../core/logging/app_log.dart';

/// FCM token + permission handling. Tokens live at
/// `users/{uid}/devices/{deviceId}` (owner-only) and never in public docs.
class PushService {
  PushService(this._messaging, this._db);

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;

  static const _deviceIdKey = 'hushlo.deviceId';
  static const _appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  Future<AuthorizationStatus> status() async =>
      (await _messaging.getNotificationSettings()).authorizationStatus;

  Future<AuthorizationStatus> requestPermission() async =>
      (await _messaging.requestPermission()).authorizationStatus;

  /// Don't show banners from FCM while foregrounded; we show our own so a
  /// chat that's already open can suppress its notification.
  Future<void> configureForeground() =>
      _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  Future<String?> _token() async {
    if (Platform.isIOS) {
      // The FCM token is only valid once the APNs token is available.
      for (var i = 0; i < 10; i++) {
        if (await _messaging.getAPNSToken() != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (await _messaging.getAPNSToken() == null) return null;
    }
    return _messaging.getToken();
  }

  Future<void> registerDevice(String uid) async {
    try {
      final token = await _token();
      if (token == null) {
        AppLog.d('push.noToken');
        return;
      }
      await _write(uid, token);
    } catch (e) {
      throw Failure.from(e);
    }
  }

  Future<void> _write(String uid, String token) async {
    final id = await _deviceId();
    await _db.doc('users/$uid/devices/$id').set({
      'token': token,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'appVersion': _appVersion,
      'lastSeenAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  Future<void> refreshToken(String uid, String token) => _write(uid, token);

  Future<void> unregisterDevice(String uid) async {
    try {
      final id = await _deviceId();
      await _db.doc('users/$uid/devices/$id').delete();
      await _messaging.deleteToken();
    } catch (_) {
      // Best effort: sign-out must never be blocked by cleanup.
    }
  }

  Stream<RemoteMessage> get onForeground => FirebaseMessaging.onMessage;

  /// Taps on a system notification while the app was backgrounded.
  Stream<RemoteMessage> get onOpened => FirebaseMessaging.onMessageOpenedApp;

  /// Tap that cold-started the app.
  Future<RemoteMessage?> initialMessage() => _messaging.getInitialMessage();
}
