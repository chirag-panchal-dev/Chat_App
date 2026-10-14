import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hushlo/core/utils/date_format.dart';
import 'package:hushlo/features/conversations/domain/entities/conversation.dart';

InboxItem item(
  String id,
  DateTime? at, {
  bool pinned = false,
  String sender = 'other',
  DateTime? read,
}) => InboxItem(
  Conversation(
    id: id,
    memberIds: ['me', 'other'],
    lastMessageAt: at,
    lastSenderId: sender,
  ),
  MemberPrefs(pinned: pinned, lastReadAt: read),
  me: 'me',
);

void main() {
  final now = DateTime(2026, 10, 14, 15);
  setUpAll(() => initializeDateFormatting('en'));

  test('inbox timestamp: time today, weekday this week, date otherwise', () {
    expect(
      DateFormatter.inbox(DateTime(2026, 10, 14, 9, 5), 'en', now: now),
      contains('9:05'),
    );
    expect(
      DateFormatter.inbox(DateTime(2026, 10, 12, 9), 'en', now: now),
      'Mon',
    );
    expect(
      DateFormatter.inbox(DateTime(2026, 9, 1), 'en', now: now),
      isNot('Tue'),
    );
  });

  test('day separator labels', () {
    String f(DateTime t) => DateFormatter.daySeparator(
      t,
      'en',
      today: 'Today',
      yesterday: 'Yesterday',
      now: now,
    );
    expect(f(DateTime(2026, 10, 14, 1)), 'Today');
    expect(f(DateTime(2026, 10, 13, 23)), 'Yesterday');
    expect(f(DateTime(2026, 1, 2)), 'Jan 2, 2026');
  });

  test('sortInbox puts pinned first then newest', () {
    final sorted = sortInbox([
      item('old', DateTime(2026, 1, 1)),
      item('new', DateTime(2026, 5, 1)),
      item('pinnedOld', DateTime(2025, 1, 1), pinned: true),
    ]);
    expect(sorted.map((i) => i.conversation.id), ['pinnedOld', 'new', 'old']);
  });

  test('unread logic', () {
    final t = DateTime(2026, 5, 1);
    expect(item('a', t).unread, isTrue);
    expect(item('a', t, read: DateTime(2026, 5, 2)).unread, isFalse);
    expect(item('a', t, sender: 'me').unread, isFalse);
    expect(item('a', null).unread, isFalse);
  });

  test('mute window', () {
    final p = MemberPrefs(mutedUntil: DateTime(2026, 10, 15));
    expect(p.isMuted(DateTime(2026, 10, 14)), isTrue);
    expect(p.isMuted(DateTime(2026, 10, 16)), isFalse);
  });
}
