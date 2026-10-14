import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hushlo/core/errors/failure.dart';
import 'package:hushlo/features/auth/presentation/viewmodels/auth_providers.dart';
import 'package:hushlo/features/chat/domain/entities/chat_message.dart';
import 'package:hushlo/features/chat/presentation/viewmodels/chat_view_model.dart';
import 'package:hushlo/features/conversations/domain/entities/conversation.dart';
import 'package:hushlo/features/conversations/presentation/viewmodels/conversation_providers.dart';
import 'package:hushlo/features/privacy_settings/domain/privacy_settings.dart';
import 'package:hushlo/features/privacy_settings/presentation/viewmodels/settings_providers.dart';

import 'fakes.dart';

void main() {
  late FakeChatRepository chat;
  late FakeConversationRepository convs;
  late ProviderContainer container;
  const cid = 'a_b';

  ChatViewModel vm() => container.read(chatViewModelProvider(cid).notifier);
  ChatState state() => container.read(chatViewModelProvider(cid));

  setUp(() {
    chat = FakeChatRepository();
    convs = FakeConversationRepository();
    container = ProviderContainer(
      overrides: [
        currentUidProvider.overrideWithValue('me'),
        chatRepositoryProvider.overrideWithValue(chat),
        conversationRepositoryProvider.overrideWithValue(convs),
      ],
    );
    // Keep the auto-dispose provider alive for the test.
    container.listen(chatViewModelProvider(cid), (_, __) {});
  });

  tearDown(() => container.dispose());

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  test('starts loading, then shows messages newest-first', () async {
    expect(state().loading, isTrue);
    chat.latest.add([
      msg('2', DateTime(2026, 1, 2)),
      msg('1', DateTime(2026, 1, 1)),
    ]);
    await pump();
    expect(state().loading, isFalse);
    expect(state().messages.map((m) => m.id), ['2', '1']);
  });

  test('blank text is rejected locally and nothing is sent', () async {
    expect(vm().sendText('   '), isFalse);
    await pump();
    expect(chat.sent, isEmpty);
    expect(state().sendError, isA<ValidationFailure>());
  });

  test('successful send writes once with trimmed text', () async {
    expect(vm().sendText('  hello  '), isTrue);
    await pump();
    expect(chat.sentTexts, ['hello']);
    expect(state().failed, isEmpty);
  });

  test('failed send keeps the message and retry reuses the same id', () async {
    chat.sendError = const PermissionFailure();
    vm().sendText('hello');
    await pump();
    expect(state().failed, hasLength(1));
    expect(state().failed.single.text, 'hello');
    final firstId = chat.sent.single;

    chat.sendError = null;
    vm().retry(firstId);
    await pump();
    expect(chat.sent, [firstId, firstId], reason: 'idempotent id on retry');
    expect(state().failed, isEmpty);
  });

  test('discard removes a failed message', () async {
    chat.sendError = const NetworkFailure();
    vm().sendText('x');
    await pump();
    vm().discard(state().failed.single.id);
    expect(state().failed, isEmpty);
  });

  test('messages hidden for me are filtered out', () async {
    chat.latest.add([
      msg('2', DateTime(2026, 1, 2)),
      msg('1', DateTime(2026, 1, 1)),
    ]);
    await pump();
    chat.hidden.add({'2'});
    await pump();
    expect(state().messages.map((m) => m.id), ['1']);
  });

  test(
    'pagination appends older page, de-duplicates and stops at short page',
    () async {
      final window = List.generate(
        40,
        (i) => msg('m$i', DateTime(2026, 1, 1).add(Duration(minutes: 100 - i))),
      );
      chat.latest.add(window);
      await pump();
      expect(state().hasMore, isTrue);

      chat.olderPage = [
        window.last, // overlap must not duplicate
        msg('old1', DateTime(2025, 12, 31)),
      ];
      await vm().loadOlder();
      expect(chat.lastCursor!.id, window.last.id);
      final ids = state().messages.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids.last, 'old1');
      expect(state().hasMore, isFalse);
    },
  );

  test('pending messages are not used as pagination cursor', () async {
    chat.latest.add([
      msg('p', DateTime(2026, 1, 3), sender: 'me', status: SendStatus.sending),
      msg('s', DateTime(2026, 1, 2)),
    ]);
    await pump();
    chat.olderPage = const [];
    await vm().loadOlder(); // hasMore is false (window < page size) so no call
    expect(chat.lastCursor, isNull);
  });

  test(
    'marks read when newest message is from the other person (debounced)',
    () async {
      chat.latest.add([msg('1', DateTime(2026, 1, 1), sender: 'other')]);
      await Future<void>.delayed(const Duration(milliseconds: 800));
      expect(convs.reads, [cid]);
      expect(chat.readMarks, [
        cid,
      ], reason: 'read receipt is shared when enabled');
    },
  );

  test('does not mark read for own messages', () async {
    chat.latest.add([msg('1', DateTime(2026, 1, 1), sender: 'me')]);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(convs.reads, isEmpty);
  });

  test('reply target is attached to the next send then cleared', () async {
    final m = msg('1', DateTime(2026, 1, 1));
    vm().setReplyTo(m);
    expect(state().replyTo, m);
    vm().sendText('answer');
    expect(state().replyTo, isNull);
  });

  test('stream error surfaces as a typed failure', () async {
    chat.latest.addError(const PermissionFailure());
    await pump();
    expect(state().error, isA<PermissionFailure>());
    expect(state().loading, isFalse);
  });

  group('delete', () {
    test('delete for me hides every selected message', () async {
      await vm().deleteForMe(['a', 'b']);
      expect(chat.hiddenCalls, ['a', 'b']);
    });

    test(
      'delete for everyone only touches my recent, undeleted messages',
      () async {
        final recent = DateTime.now().subtract(const Duration(minutes: 5));
        final old = DateTime.now().subtract(const Duration(hours: 49));
        chat.latest.add([
          msg('mine', recent, sender: 'me'),
          msg('theirs', recent, sender: 'other'),
          msg('mineOld', old, sender: 'me'),
        ]);
        await pump();
        await vm().deleteForEveryone(['mine', 'theirs', 'mineOld']);
        expect(chat.deletedForEveryone, ['mine']);
      },
    );
  });

  group('reaction toggle', () {
    test('tapping the emoji you already used removes it', () {
      expect(nextReaction('👍', '👍'), isNull);
    });
    test('a different emoji replaces your reaction', () {
      expect(nextReaction('👍', '❤️'), '❤️');
    });
    test('first reaction is set', () {
      expect(nextReaction(null, '😂'), '😂');
    });
  });

  group('typing indicator', () {
    setUp(() {
      ChatViewModel.typingThrottle = const Duration(milliseconds: 80);
      ChatViewModel.typingIdle = const Duration(milliseconds: 120);
    });
    tearDown(() {
      ChatViewModel.typingThrottle = const Duration(seconds: 3);
      ChatViewModel.typingIdle = const Duration(seconds: 4);
    });

    ProviderContainer withSettings(bool showLastSeen) {
      final c = ProviderContainer(
        overrides: [
          currentUidProvider.overrideWithValue('me'),
          chatRepositoryProvider.overrideWithValue(chat),
          conversationRepositoryProvider.overrideWithValue(convs),
          settingsProvider.overrideWith(
            (ref) => Stream.value(PrivacySettings(showLastSeen: showLastSeen)),
          ),
        ],
      );
      c.listen(chatViewModelProvider(cid), (_, __) {});
      c.listen(settingsProvider, (_, __) {}); // loaded, as in the running app
      return c;
    }

    test('typing is throttled to one signal per window', () async {
      final c = withSettings(true);
      addTearDown(c.dispose);
      await pump();
      final v = c.read(chatViewModelProvider(cid).notifier);
      for (var i = 0; i < 6; i++) {
        v.typingChanged('hel' * (i + 1));
      }
      await pump();
      expect(chat.typingSet.length, 1);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      v.typingChanged('hello again');
      await pump();
      expect(chat.typingSet.length, 2);
    });

    test('clears after idle and when the text is emptied', () async {
      final c = withSettings(true);
      addTearDown(c.dispose);
      await pump();
      final v = c.read(chatViewModelProvider(cid).notifier);
      v.typingChanged('hi');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(chat.typingCleared, 1, reason: 'idle timeout clears');
      v.typingChanged('again');
      await pump();
      v.typingChanged('');
      await pump();
      expect(chat.typingCleared, 2, reason: 'emptying the box clears');
    });

    test('sending clears the signal', () async {
      final c = withSettings(true);
      addTearDown(c.dispose);
      await pump();
      final v = c.read(chatViewModelProvider(cid).notifier);
      v.typingChanged('hello');
      await pump();
      v.sendText('hello');
      await pump();
      expect(chat.typingCleared, 1);
    });

    test('nothing is sent when last seen & typing is switched off', () async {
      final c = withSettings(false);
      addTearDown(c.dispose);
      await pump();
      c.read(chatViewModelProvider(cid).notifier).typingChanged('hello');
      await pump();
      expect(chat.typingSet, isEmpty);
    });
  });

  group('isTypingNow', () {
    test('expires after the window', () {
      final t = DateTime(2026, 1, 1, 12);
      expect(isTypingNow(t, t.add(const Duration(seconds: 3))), isTrue);
      expect(isTypingNow(t, t.add(const Duration(seconds: 7))), isFalse);
      expect(isTypingNow(null), isFalse);
    });
  });

  group('clear chat', () {
    test('messages up to the clear time disappear; newer ones stay', () async {
      chat.latest.add([
        msg('3', DateTime(2026, 1, 3)),
        msg('2', DateTime(2026, 1, 2)),
        msg('1', DateTime(2026, 1, 1)),
      ]);
      await pump();
      expect(state().messages.length, 3);
      convs.prefsController.add(MemberPrefs(clearedAt: DateTime(2026, 1, 2)));
      await pump();
      expect(state().messages.map((m) => m.id), ['3']);
    });

    test('a just-sent (pending) message is never hidden by clearing', () async {
      convs.prefsController.add(MemberPrefs(clearedAt: DateTime(2026, 6, 1)));
      await pump();
      chat.latest.add([
        msg(
          'p',
          DateTime(2026, 1, 1),
          sender: 'me',
          status: SendStatus.sending,
        ),
      ]);
      await pump();
      expect(state().messages.map((m) => m.id), ['p']);
    });

    test('clearChat writes through the repository', () async {
      expect(await vm().clearChat(), isTrue);
      expect(convs.cleared, [cid]);
    });
  });
}
