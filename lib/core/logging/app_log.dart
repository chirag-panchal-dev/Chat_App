import 'package:flutter/foundation.dart';

/// Minimal structured logger. Debug builds only; never pass message text,
/// emails, usernames, tokens or media URLs.
abstract final class AppLog {
  static void d(String event, [Map<String, Object?> fields = const {}]) {
    if (!kDebugMode) return;
    final f = fields.entries.map((e) => '${e.key}=${e.value}').join(' ');
    debugPrint('[hushlo] $event $f');
  }
}
