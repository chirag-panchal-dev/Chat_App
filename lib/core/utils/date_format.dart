import 'package:intl/intl.dart';

/// Locale-aware formatting. All timestamps are displayed in the device's local
/// time zone; Firestore stores UTC server timestamps.
abstract final class DateFormatter {
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String time(DateTime t, String locale) =>
      DateFormat.jm(locale).format(t.toLocal());

  /// Compact inbox timestamp: time today, weekday this week, else date.
  static String inbox(DateTime t, String locale, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final l = t.toLocal();
    if (_sameDay(l, n)) return DateFormat.jm(locale).format(l);
    if (n.difference(l).inDays < 7 && l.isBefore(n)) {
      return DateFormat.E(locale).format(l);
    }
    return DateFormat.yMd(locale).format(l);
  }

  static String daySeparator(
    DateTime t,
    String locale, {
    required String today,
    required String yesterday,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final l = t.toLocal();
    if (_sameDay(l, n)) return today;
    if (_sameDay(l, n.subtract(const Duration(days: 1)))) return yesterday;
    return DateFormat.yMMMd(locale).format(l);
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      _sameDay(a.toLocal(), b.toLocal());
}
