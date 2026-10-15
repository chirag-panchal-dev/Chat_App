/// How long Hushlo may stay in the background before it asks to unlock again.
enum AppLockTimeout {
  immediately(Duration.zero),
  oneMinute(Duration(minutes: 1)),
  fiveMinutes(Duration(minutes: 5)),
  fifteenMinutes(Duration(minutes: 15)),
  oneHour(Duration(hours: 1));

  const AppLockTimeout(this.duration);
  final Duration duration;

  static AppLockTimeout fromName(String? name) =>
      AppLockTimeout.values.firstWhere(
        (t) => t.name == name,
        orElse: () => AppLockTimeout.oneMinute,
      );
}

/// Device-local App lock preferences (not synced: each phone decides).
class AppLockSettings {
  const AppLockSettings({
    this.enabled = false,
    this.timeout = AppLockTimeout.oneMinute,
    this.hidePreview = true,
  });

  final bool enabled;
  final AppLockTimeout timeout;

  /// Cover the app with a privacy screen in the app switcher.
  final bool hidePreview;

  AppLockSettings copyWith({
    bool? enabled,
    AppLockTimeout? timeout,
    bool? hidePreview,
  }) => AppLockSettings(
    enabled: enabled ?? this.enabled,
    timeout: timeout ?? this.timeout,
    hidePreview: hidePreview ?? this.hidePreview,
  );
}

enum AuthOutcome { success, failed, cancelled, lockedOut, notAvailable }

/// Result of trying to turn App lock on or off.
enum LockChange { done, notAvailable, failed }

/// Pure policy: should the app lock when it returns to the foreground?
bool shouldLockOnResume({
  required bool enabled,
  required DateTime? leftAt,
  required DateTime now,
  required Duration timeout,
}) {
  if (!enabled || leftAt == null) return false;
  return now.difference(leftAt) >= timeout;
}
