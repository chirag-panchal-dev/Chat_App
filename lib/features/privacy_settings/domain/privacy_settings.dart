import 'package:flutter/material.dart';

import 'quiet_hours.dart';

/// Per-user private settings (spec §9.2).
///
/// `showLastSeen` maps to the stored `lastSeenVisibility` field
/// ('contacts_or_chat_members' = on, 'nobody' = off).
class PrivacySettings {
  const PrivacySettings({
    this.notificationEnabled = true,
    this.showMessagePreview = false,
    this.readReceiptsEnabled = true,
    this.showLastSeen = true,
    this.themeMode = ThemeMode.system,
    this.quietHours = const QuietHours(),
  });

  /// Notifications arrive silently inside this daily window.
  final QuietHours quietHours;

  final bool notificationEnabled;
  final bool showMessagePreview;
  final bool readReceiptsEnabled;
  final bool showLastSeen;
  final ThemeMode themeMode;

  PrivacySettings copyWith({
    bool? notificationEnabled,
    bool? showMessagePreview,
    bool? readReceiptsEnabled,
    bool? showLastSeen,
    ThemeMode? themeMode,
    QuietHours? quietHours,
  }) => PrivacySettings(
    notificationEnabled: notificationEnabled ?? this.notificationEnabled,
    showMessagePreview: showMessagePreview ?? this.showMessagePreview,
    readReceiptsEnabled: readReceiptsEnabled ?? this.readReceiptsEnabled,
    showLastSeen: showLastSeen ?? this.showLastSeen,
    themeMode: themeMode ?? this.themeMode,
    quietHours: quietHours ?? this.quietHours,
  );
}

abstract interface class SettingsRepository {
  Stream<PrivacySettings> watchSettings(String uid);
  Future<void> setNotificationEnabled(String uid, bool value);
  Future<void> setShowMessagePreview(String uid, bool value);
  Future<void> setReadReceipts(String uid, bool value);
  Future<void> setShowLastSeen(String uid, bool value);
  Future<void> setThemeMode(String uid, ThemeMode mode);

  /// Saves the quiet-hours window and the phone's current UTC offset (the
  /// server uses it to know what local time it is for this user).
  Future<void> setQuietHours(
    String uid,
    QuietHours quiet, {
    required int utcOffsetMin,
  });

  /// Keeps the stored UTC offset current (travel, daylight saving).
  Future<void> syncUtcOffset(String uid, int utcOffsetMin);
}
