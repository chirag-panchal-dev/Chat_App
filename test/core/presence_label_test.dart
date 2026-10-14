import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hushlo/features/presence/domain/presence_label.dart';
import 'package:hushlo/l10n/app_localizations.dart';

void main() {
  late AppL10n l;
  final now = DateTime(2026, 10, 14, 17, 30);

  setUpAll(() async {
    await initializeDateFormatting('en');
    l = await AppL10n.delegate.load(const Locale('en'));
  });

  test('unknown/hidden presence has no label', () {
    expect(presenceLabel(l, null, 'en', now: now), isNull);
    expect(isOnline(null), isFalse);
  });

  test('recent heartbeat is online', () {
    final t = now.subtract(const Duration(seconds: 90));
    expect(isOnline(t, now), isTrue);
    expect(presenceLabel(l, t, 'en', now: now), 'online');
  });

  test('beyond the online window becomes last seen today', () {
    final t = now.subtract(const Duration(minutes: 10));
    expect(isOnline(t, now), isFalse);
    expect(presenceLabel(l, t, 'en', now: now), contains('last seen today at'));
    expect(presenceLabel(l, t, 'en', now: now), contains('5:20'));
  });

  test('yesterday and older dates', () {
    expect(
      presenceLabel(l, DateTime(2026, 10, 13, 22, 5), 'en', now: now),
      contains('last seen yesterday at'),
    );
    expect(
      presenceLabel(l, DateTime(2026, 9, 1, 8), 'en', now: now),
      'last seen Sep 1, 2026',
    );
  });
}
