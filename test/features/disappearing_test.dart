import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hushlo/features/auth/presentation/viewmodels/auth_providers.dart';
import 'package:hushlo/features/chat/domain/entities/chat_message.dart';
import 'package:hushlo/features/chat/presentation/viewmodels/chat_view_model.dart';
import 'package:hushlo/features/conversations/domain/entities/conversation.dart';
import 'package:hushlo/features/conversations/presentation/viewmodels/conversation_providers.dart';
import 'package:hushlo/features/conversations/presentation/widgets/disappearing_tile.dart';
import 'package:hushlo/features/groups/presentation/widgets/system_message_row.dart';

import '../helpers/pump_app.dart';
import 'fakes.dart';

ChatMessage timed(String id, {DateTime? expires}) => ChatMessage(
  id: id,
  senderId: 'other',
  type: MessageType.text,
  createdAt: DateTime(2026, 1, 1),
  status: SendStatus.sent,
  text: 'x',
  expiresAt: expires,
);

void main() {
  group('expiry', () {
    final now = DateTime(2026, 6, 1, 12);
    test('no expiresAt never expires', () {
      expect(timed('a').isExpired(now), isFalse);
    });
    test('future is visible, past and exactly-now are expired', () {
      expect(
        timed('a', expires: now.add(const Duration(minutes: 1))).isExpired(now),
        isFalse,
      );
      expect(timed('a', expires: now).isExpired(now), isTrue);
      expect(
        timed(
          'a',
          expires: now.subtract(const Duration(days: 1)),
        ).isExpired(now),
        isTrue,
      );
    });
    test('the timeline hides expired messages', () {
      final s = ChatState(
        latest: [
          timed(
            'gone',
            expires: DateTime.now().subtract(const Duration(hours: 1)),
          ),
          timed('kept', expires: DateTime.now().add(const Duration(hours: 1))),
          timed('plain'),
        ],
      );
      expect(s.messages.map((m) => m.id), unorderedEquals(['kept', 'plain']));
    });
    test('conversation timer maps to a Duration (0 = off)', () {
      const off = Conversation(id: 'a_b', memberIds: ['a', 'b']);
      const on = Conversation(
        id: 'a_b',
        memberIds: ['a', 'b'],
        disappearAfterSec: 86400,
      );
      expect(off.disappearAfter, isNull);
      expect(on.disappearAfter, const Duration(hours: 24));
    });
  });

  group('DisappearingTile', () {
    testWidgets('shows the current timer and changes it', (t) async {
      final convs =
          FakeConversationRepository()
            ..current = const Conversation(
              id: 'a_b',
              memberIds: ['a', 'me'],
              disappearAfterSec: 604800,
            );
      await t.pumpApp(
        const Scaffold(body: DisappearingTile(conversationId: 'a_b', me: 'me')),
        overrides: [
          currentUidProvider.overrideWithValue('me'),
          conversationRepositoryProvider.overrideWithValue(convs),
        ],
      );
      await t.pump();
      expect(find.text('7 days'), findsOneWidget);
      await t.tap(find.byType(ListTile));
      await t.pumpAndSettle();
      await t.tap(find.text('24 hours'));
      await t.pumpAndSettle();
      expect(convs.timers['a_b'], 86400);
    });

    testWidgets('non-admins cannot change it', (t) async {
      final convs = FakeConversationRepository();
      await t.pumpApp(
        const Scaffold(
          body: DisappearingTile(
            conversationId: 'g',
            me: 'me',
            canChange: false,
          ),
        ),
        overrides: [conversationRepositoryProvider.overrideWithValue(convs)],
      );
      await t.pump();
      expect(find.textContaining('Only admins'), findsOneWidget);
      await t.tap(find.byType(ListTile));
      await t.pumpAndSettle();
      expect(find.text('24 hours'), findsNothing);
    });
  });

  testWidgets('timer notices read naturally', (t) async {
    ChatMessage notice(int sec) => ChatMessage(
      id: 'n',
      senderId: 'me',
      type: MessageType.system,
      createdAt: DateTime(2026),
      status: SendStatus.sent,
      event: GroupEvent.timer,
      timerSec: sec,
    );
    await t.pumpApp(SystemMessageRow(message: notice(604800), me: 'me'));
    expect(
      find.text('You set messages to disappear after 7 days'),
      findsOneWidget,
    );
    await t.pumpApp(SystemMessageRow(message: notice(0), me: 'me'));
    expect(find.text('You turned off disappearing messages'), findsOneWidget);
  });
}
