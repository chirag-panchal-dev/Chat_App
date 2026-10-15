/// A daily window in which notifications arrive silently (no sound or
/// vibration). Times are minutes after local midnight, so 22:00 = 1320. A
/// window may cross midnight (22:00 -> 07:00). Equal start and end is empty.
class QuietHours {
  const QuietHours({
    this.enabled = false,
    this.startMin = 22 * 60,
    this.endMin = 7 * 60,
  });

  final bool enabled;
  final int startMin;
  final int endMin;

  static const minutesPerDay = 24 * 60;

  /// Whether [localTime] (in the user's own time zone) is inside the window.
  bool contains(DateTime localTime) {
    if (!enabled || startMin == endMin) return false;
    final m = localTime.hour * 60 + localTime.minute;
    return startMin < endMin
        ? m >= startMin && m < endMin
        : m >= startMin || m < endMin;
  }

  QuietHours copyWith({bool? enabled, int? startMin, int? endMin}) =>
      QuietHours(
        enabled: enabled ?? this.enabled,
        startMin: startMin ?? this.startMin,
        endMin: endMin ?? this.endMin,
      );

  static bool validMinute(Object? v) => v is int && v >= 0 && v < minutesPerDay;
}
