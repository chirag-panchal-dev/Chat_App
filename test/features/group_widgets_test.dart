import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hushlo/features/chat/domain/entities/chat_message.dart';
import 'package:hushlo/features/chat/presentation/viewmodels/chat_view_model.dart';
import 'package:hushlo/features/chat/presentation/widgets/message_bubble.dart';
import 'package:hushlo/features/groups/presentation/widgets/system_message_row.dart';
import 'package:hushlo/features/profile/domain/entities/profile.dart';
import 'package:hushlo/features/profile/presentation/viewmodels/profile_providers.dart';

import '../helpers/pump_app.dart';
import 'fakes.dart';

ChatMessage sys(GroupEvent e, {String sender = 'me', String? target}) =>
    ChatMessage(
      id: 's',
      senderId: sender,
      type: MessageType.system,
      createdAt: DateTime(2026, 1, 1, 9),
      status: SendStatus.sent,
      event: e,
      targetUid: target,
    );

void main() {
  final overrides = [
    profileByUidProvider.overrideWith(
      (ref, uid) async => switch (uid) {
        'aarav' => const Profile(
          uid: 'aarav',
          username: 'aarav',
          displayName: 'Aarav Sharma',
        ),
        'meera' => const Profile(
          uid: 'meera',
          username: 'meera',
          displayName: 'Meera Patel',
        ),
        _ => null,
      },
    ),
  ];

  group('SystemMessageRow', () {
    Future<void> show(WidgetTester t, ChatMessage m) async {
      await t.pumpApp(
        Scaffold(body: SystemMessageRow(message: m, me: 'me')),
        overrides: overrides,
      );
      await t.pump();
      await t.pump();
    }

    testWidgets('"You added <name>"', (t) async {
      await show(t, sys(GroupEvent.added, target: 'meera'));
      expect(find.text('You added Meera Patel'), findsOneWidget);
    });

    testWidgets('someone else added you', (t) async {
      await show(t, sys(GroupEvent.added, sender: 'aarav', target: 'me'));
      expect(find.text('Aarav Sharma added you'), findsOneWidget);
    });

    testWidgets('removed and left', (t) async {
      await show(t, sys(GroupEvent.removed, target: 'aarav'));
      expect(find.text('You removed Aarav Sharma'), findsOneWidget);
      await show(t, sys(GroupEvent.left, sender: 'meera', target: 'meera'));
      expect(find.text('Meera Patel left'), findsOneWidget);
    });

    testWidgets('renamed', (t) async {
      await show(t, sys(GroupEvent.renamed, sender: 'aarav'));
      expect(find.text('Aarav Sharma changed the group name'), findsOneWidget);
    });
  });

  group('Group message bubble', () {
    final base = [
      chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
    ];

    testWidgets('shows the sender name and avatar slot for incoming messages', (
      t,
    ) async {
      await t.pumpApp(
        Scaffold(
          body: MessageBubble(
            conversationId: 'g',
            message: msg(
              '1',
              DateTime(2026, 1, 1, 9),
              sender: 'aarav',
              text: 'hello team',
            ),
            mine: false,
            myUid: 'me',
            senderName: 'Aarav Sharma',
            avatarSlot: const SizedBox(
              key: ValueKey('avatar'),
              width: 28,
              height: 28,
            ),
          ),
        ),
        overrides: base,
      );
      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('hello team'), findsOneWidget);
      expect(find.byKey(const ValueKey('avatar')), findsOneWidget);
    });

    testWidgets('own messages never show a sender name', (t) async {
      await t.pumpApp(
        Scaffold(
          body: MessageBubble(
            conversationId: 'g',
            message: msg(
              '1',
              DateTime(2026, 1, 1, 9),
              sender: 'me',
              text: 'mine',
            ),
            mine: true,
            myUid: 'me',
            senderName: 'Me',
          ),
        ),
        overrides: base,
      );
      expect(find.text('Me'), findsNothing);
    });
  });
}
