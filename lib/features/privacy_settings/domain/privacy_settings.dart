import 'package:flutter/material.dart';

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
  });

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
  }) => PrivacySettings(
    notificationEnabled: notificationEnabled ?? this.notificationEnabled,
    showMessagePreview: showMessagePreview ?? this.showMessagePreview,
    readReceiptsEnabled: readReceiptsEnabled ?? this.readReceiptsEnabled,
    showLastSeen: showLastSeen ?? this.showLastSeen,
    themeMode: themeMode ?? this.themeMode,
  );
}

abstract interface class SettingsRepository {
  Stream<PrivacySettings> watchSettings(String uid);
  Future<void> setNotificationEnabled(String uid, bool value);
  Future<void> setShowMessagePreview(String uid, bool value);
  Future<void> setReadReceipts(String uid, bool value);
  Future<void> setShowLastSeen(String uid, bool value);
  Future<void> setThemeMode(String uid, ThemeMode mode);
}
