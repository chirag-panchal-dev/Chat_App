import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/errors/failure.dart';
import '../domain/privacy_settings.dart';
import '../domain/quiet_hours.dart';

class FirestoreSettingsRepository implements SettingsRepository {
  FirestoreSettingsRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.doc('users/$uid/private/settings');

  static ThemeMode _theme(Object? v) => switch (v) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  @override
  Stream<PrivacySettings> watchSettings(String uid) => _doc(uid)
      .snapshots()
      .map((s) {
        final d = s.data();
        if (d == null) return const PrivacySettings();
        return PrivacySettings(
          notificationEnabled: d['notificationEnabled'] as bool? ?? true,
          showMessagePreview: d['showMessagePreview'] as bool? ?? false,
          readReceiptsEnabled: d['readReceiptsEnabled'] as bool? ?? true,
          showLastSeen: d['lastSeenVisibility'] != 'nobody',
          themeMode: _theme(d['themeMode']),
          quietHours: QuietHours(
            enabled: d['quietHoursEnabled'] as bool? ?? false,
            startMin:
                QuietHours.validMinute(d['quietStartMin'])
                    ? d['quietStartMin'] as int
                    : 22 * 60,
            endMin:
                QuietHours.validMinute(d['quietEndMin'])
                    ? d['quietEndMin'] as int
                    : 7 * 60,
          ),
        );
      })
      .handleError((Object e) => throw Failure.from(e));

  Future<void> _merge(String uid, Map<String, Object?> data) async {
    try {
      await _doc(uid).set({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Failure.from(e);
    }
  }

  @override
  Future<void> setNotificationEnabled(String uid, bool value) =>
      _merge(uid, {'notificationEnabled': value});

  @override
  Future<void> setShowMessagePreview(String uid, bool value) =>
      _merge(uid, {'showMessagePreview': value});

  @override
  Future<void> setReadReceipts(String uid, bool value) =>
      _merge(uid, {'readReceiptsEnabled': value});

  @override
  Future<void> setShowLastSeen(String uid, bool value) => _merge(uid, {
    'lastSeenVisibility': value ? 'contacts_or_chat_members' : 'nobody',
  });

  @override
  Future<void> setQuietHours(
    String uid,
    QuietHours q, {
    required int utcOffsetMin,
  }) => _merge(uid, {
    'quietHoursEnabled': q.enabled,
    'quietStartMin': q.startMin,
    'quietEndMin': q.endMin,
    'utcOffsetMin': utcOffsetMin,
  });

  @override
  Future<void> syncUtcOffset(String uid, int utcOffsetMin) =>
      _merge(uid, {'utcOffsetMin': utcOffsetMin});

  @override
  Future<void> setThemeMode(String uid, ThemeMode mode) =>
      _merge(uid, {'themeMode': mode.name});
}
