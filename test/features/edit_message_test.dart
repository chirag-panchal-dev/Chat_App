import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hushlo/core/errors/failure.dart';
import 'package:hushlo/features/auth/presentation/viewmodels/auth_providers.dart';
import 'package:hushlo/features/chat/domain/entities/chat_message.dart';
import 'package:hushlo/features/chat/presentation/viewmodels/chat_view_model.dart';
import 'package:hushlo/features/chat/presentation/widgets/inline_edit_bubble.dart';
import 'package:hushlo/features/chat/presentation/widgets/message_bubble.dart';
import 'package:hushlo/features/conversations/presentation/viewmodels/conversation_providers.dart';

import '../helpers/pump_app.dart';
import 'fakes.dart';

ChatMessage mine(
  String id, {
  Duration age = const Duration(minutes: 1),
  String text = 'helo',
  SendStatus status = SendStatus.sent,
  bool deleted = false,
  MessageType type = MessageType.text,
  DateTime? editedAt,
}) => ChatMessage(
  id: id,
  senderId: 'me',
  type: type,
  createdAt: DateTime.now().subtract(age),
  status: status,
  text: text,
  deleted: deleted,
  editedAt: editedAt,
);

void main() {
  group('canEdit', () {
    test('own recent sent text message', () {
      expect(mine('a').canEdit('me'), isTrue);
    });
    test('not after 15 minutes', () {
      expect(
        mine('a', age: const Duration(minutes: 16)).canEdit('me'),
        isFalse,
      );
      expect(mine('a', age: const Duration(minutes: 14)).canEdit('me'), isTrue);
    });
    test('not someone else\'s, pending, deleted, or photos', () {
      expect(mine('a').canEdit('other'), isFalse);
      expect(mine('a', status: SendStatus.sending).canEdit('me'), isFalse);
      expect(mine('a', deleted: true).canEdit('me'), isFalse);
      expect(mine('a', type: MessageType.image).canEdit('me'), isFalse);
      expect(mine('a', type: MessageType.voice).canEdit('me'), isFalse);
    });
  });

  group('view-model editing', () {
    late FakeChatRepository chat;
    late ProviderContainer c;
    const cid = 'a_b';
    ChatViewModel vm() => c.read(chatViewModelProvider(cid).notifier);
    ChatState st() => c.read(chatViewModelProvider(cid));
    Future<void> pump() => Future<void>.delayed(Duration.zero);

    setUp(() {
      chat = FakeChatRepository();
      c = ProviderContainer(
        overrides: [
          currentUidProvider.overrideWithValue('me'),
          chatRepositoryProvider.overrideWithValue(chat),
          conversationRepositoryProvider.overrideWithValue(
            FakeConversationRepository(),
          ),
        ],
      );
      c.listen(chatViewModelProvider(cid), (_, __) {});
    });
    tearDown(() => c.dispose());

    test(
      'sending while editing saves the edit and sends no new message',
      () async {
        vm().startEdit(mine('m1'));
        expect(st().editing?.id, 'm1');
        expect(vm().saveEdit('  hello  '), isTrue);
        await pump();
        expect(chat.edits, {'m1': 'hello'});
        expect(chat.sent, isEmpty);
        expect(st().editing, isNull);
      },
    );

    test('unchanged text is a no-op', () async {
      vm().startEdit(mine('m1', text: 'same'));
      vm().saveEdit('same');
      await pump();
      expect(chat.edits, isEmpty);
      expect(st().editing, isNull);
    });

    test('blank text is rejected and the edit stays open', () async {
      vm().startEdit(mine('m1'));
      expect(vm().saveEdit('   '), isFalse);
      expect(st().sendError, isA<ValidationFailure>());
      expect(st().editing?.id, 'm1');
    });

    test('window passed while typing: rejected, nothing written', () async {
      vm().startEdit(mine('m1', age: const Duration(minutes: 16)));
      vm().saveEdit('late');
      await pump();
      expect(chat.edits, isEmpty);
      expect(st().sendError, isA<PermissionFailure>());
    });

    test('server rejection surfaces as an error', () async {
      chat.editError = const PermissionFailure();
      vm().startEdit(mine('m1'));
      vm().saveEdit('x');
      await pump();
      expect(st().sendError, isA<PermissionFailure>());
    });

    test('starting a reply cancels the edit and vice versa', () {
      vm().startEdit(mine('m1'));
      vm().setReplyTo(mine('m2'));
      expect(st().editing, isNull);
      vm().startEdit(mine('m1'));
      expect(st().replyTo, isNull);
    });
  });

  group('inline editor', () {
    testWidgets('edits in place and saves', (t) async {
      String? saved;
      await t.pumpApp(
        Scaffold(
          body: InlineEditBubble(
            initialText: 'original',
            onSave: (v) => saved = v,
            onCancel: () {},
          ),
        ),
      );
      expect(find.text('original'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'changed');
      await t.pump();
      await t.tap(find.byTooltip('Save edit'));
      expect(saved, 'changed');
    });

    testWidgets('save is disabled when emptied; cancel works', (t) async {
      var cancelled = false;
      await t.pumpApp(
        Scaffold(
          body: InlineEditBubble(
            initialText: 'original',
            onSave: (_) {},
            onCancel: () => cancelled = true,
          ),
        ),
      );
      await t.enterText(find.byType(TextField), '  ');
      await t.pump();
      expect(
        t
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.check_rounded),
            )
            .onPressed,
        isNull,
      );
      await t.tap(find.byIcon(Icons.close_rounded));
      expect(cancelled, isTrue);
    });
  });

  testWidgets('an edited message shows the Edited label', (t) async {
    await t.pumpApp(
      Scaffold(
        body: MessageBubble(
          conversationId: 'c',
          message: mine('m1', text: 'fixed', editedAt: DateTime.now()),
          mine: true,
          myUid: 'me',
        ),
      ),
      overrides: [
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
      ],
    );
    expect(find.textContaining('Edited'), findsOneWidget);
  });
}
