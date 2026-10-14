import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';

/// How long after the last heartbeat someone still counts as online.
const onlineWindow = Duration(seconds: 150);

bool isOnline(DateTime? lastActive, [DateTime? now]) =>
    lastActive != null &&
    (now ?? DateTime.now()).difference(lastActive) < onlineWindow;

/// WhatsApp-style label: "online", "last seen today at 5:20 PM",
/// "last seen yesterday at …", or "last seen {date}". Null when unknown.
String? presenceLabel(
  AppL10n l,
  DateTime? lastActive,
  String locale, {
  DateTime? now,
}) {
  if (lastActive == null) return null;
  final n = now ?? DateTime.now();
  if (isOnline(lastActive, n)) return l.online;
  final t = lastActive.toLocal();
  final time = DateFormat.jm(locale).format(t);
  bool same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  if (same(t, n)) return l.lastSeenToday(time);
  if (same(t, n.subtract(const Duration(days: 1)))) {
    return l.lastSeenYesterday(time);
  }
  return l.lastSeenOn(DateFormat.yMMMd(locale).format(t));
}
