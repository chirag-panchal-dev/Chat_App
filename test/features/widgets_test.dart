import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hushlo/core/errors/failure.dart';
import 'package:hushlo/core/widgets/state_views.dart';
import 'package:hushlo/features/auth/presentation/screens/auth_screen.dart';
import 'package:hushlo/features/auth/presentation/viewmodels/auth_providers.dart';
import 'package:hushlo/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:hushlo/features/chat/domain/entities/chat_message.dart';
import 'package:hushlo/features/chat/presentation/viewmodels/chat_view_model.dart';
import 'package:hushlo/features/chat/presentation/widgets/composer.dart';
import 'package:hushlo/features/chat/presentation/widgets/message_bubble.dart';
import 'package:hushlo/features/auth/domain/entities/app_user.dart';
import 'package:hushlo/features/auth/domain/repositories/auth_repository.dart';

import '../helpers/pump_app.dart';
import 'fakes.dart';

class _FakeAuth implements AuthRepository {
  final calls = <String>[];
  Object? error;
  @override
  Stream<AppUser?> authState() => const Stream.empty();
  @override
  Future<void> signInWithEmail(String e, String p) async {
    calls.add('signIn:$e');
    if (error != null) throw error!;
  }

  @override
  Future<void> signUpWithEmail(String e, String p) async =>
      calls.add('signUp:$e');
  @override
  Future<void> sendPasswordReset(String email) async =>
      calls.add('reset:$email');
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signInWithApple() async {}
  @override
  Future<void> sendEmailVerification() async {}
  @override
  Future<void> reloadUser() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<void> reauthenticateWithPassword(String p) async {}
  @override
  Future<void> reauthenticateWithProvider() async {}
}

void main() {
  group('Composer', () {
    testWidgets('send is disabled until trimmed text is non-empty', (t) async {
      final sent = <String>[];
      await t.pumpApp(
        Scaffold(
          body: Composer(
            onSend: (s) {
              sent.add(s);
              return true;
            },
            onAttach: () {},
          ),
        ),
      );
      IconButton send() => t.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.send_rounded),
      );
      expect(send().onPressed, isNull);

      await t.enterText(find.byType(TextField), '   ');
      await t.pump();
      expect(send().onPressed, isNull);

      await t.enterText(find.byType(TextField), 'hello');
      await t.pump();
      expect(send().onPressed, isNotNull);

      await t.tap(find.byTooltip('Send'));
      await t.pump();
      expect(sent, ['hello']);
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });

    testWidgets('keeps the text when send is rejected', (t) async {
      await t.pumpApp(
        Scaffold(body: Composer(onSend: (_) => false, onAttach: () {})),
      );
      await t.enterText(find.byType(TextField), 'keep me');
      await t.pump();
      await t.tap(find.byTooltip('Send'));
      await t.pump();
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        'keep me',
      );
    });

    testWidgets('icon-only controls have semantic labels and 48dp targets', (
      t,
    ) async {
      await t.pumpApp(
        Scaffold(body: Composer(onSend: (_) => true, onAttach: () {})),
      );
      expect(find.byTooltip('Attach photo'), findsOneWidget);
      final size = t.getSize(find.byTooltip('Send'));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('MessageBubble', () {
    Widget bubble(ChatMessage m, {bool mine = true}) => Scaffold(
      body: SingleChildScrollView(
        child: MessageBubble(
          conversationId: 'c',
          message: m,
          mine: mine,
          myUid: 'me',
        ),
      ),
    );
    final overrides = [
      chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
    ];

    testWidgets('shows a non-colour pending indicator, then sent', (t) async {
      await t.pumpApp(
        bubble(
          msg(
            '1',
            DateTime(2026, 1, 1, 9),
            sender: 'me',
            status: SendStatus.sending,
          ),
        ),
        overrides: overrides,
      );
      expect(find.bySemanticsLabel('Sending'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);

      await t.pumpApp(
        bubble(msg('1', DateTime(2026, 1, 1, 9), sender: 'me')),
        overrides: overrides,
      );
      expect(find.bySemanticsLabel('Sent'), findsOneWidget);
      expect(find.byIcon(Icons.done_rounded), findsOneWidget);
    });

    testWidgets('incoming bubble has no status icon', (t) async {
      await t.pumpApp(
        bubble(msg('1', DateTime(2026, 1, 1)), mine: false),
        overrides: overrides,
      );
      expect(find.byIcon(Icons.done_rounded), findsNothing);
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
    });

    for (final mode in ThemeMode.values.where((m) => m != ThemeMode.system)) {
      testWidgets(
        'renders long text at 2x font scale without overflow ($mode)',
        (t) async {
          await t.pumpApp(
            bubble(msg('1', DateTime(2026, 1, 1), text: 'word ' * 200)),
            overrides: overrides,
            textScale: 2.0,
            mode: mode,
          );
          expect(t.takeException(), isNull);
        },
      );
    }
  });

  group('reply jump and reaction toggle', () {
    ChatMessage reply() => ChatMessage(
      id: '2',
      senderId: 'other',
      type: MessageType.text,
      createdAt: DateTime(2026, 1, 1, 9),
      status: SendStatus.sent,
      text: 'sure',
      replyToId: '1',
    );
    final original = msg('1', DateTime(2026, 1, 1, 8), text: 'original text');

    testWidgets('tapping the quoted message calls onReplyTap', (t) async {
      var jumped = 0;
      await t.pumpApp(
        Scaffold(
          body: MessageBubble(
            conversationId: 'c',
            message: reply(),
            mine: false,
            myUid: 'me',
            replyTarget: original,
            onReplyTap: () => jumped++,
          ),
        ),
        overrides: [
          chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
        ],
      );
      await t.tap(find.text('original text'));
      expect(jumped, 1);
    });

    testWidgets('tapping a reaction chip reports its emoji', (t) async {
      String? tapped;
      await t.pumpApp(
        Scaffold(
          body: MessageBubble(
            conversationId: 'c',
            message: msg('1', DateTime(2026, 1, 1, 9)),
            mine: false,
            myUid: 'me',
            onReactionTap: (e) => tapped = e,
          ),
        ),
        overrides: [
          chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
          reactionsProvider((
            cid: 'c',
            mid: '1',
          )).overrideWith((ref) => Stream.value({'me': '👍', 'x': '👍'})),
        ],
      );
      await t.pump();
      await t.tap(find.textContaining('👍'));
      expect(tapped, '👍');
    });
  });

  group('deleted message tombstone', () {
    final overrides = [
      chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
    ];
    ChatMessage tomb(String sender) => ChatMessage(
      id: 'd',
      senderId: sender,
      type: MessageType.text,
      createdAt: DateTime(2026, 1, 1, 9),
      status: SendStatus.sent,
      deleted: true,
    );

    testWidgets('shows who deleted it and hides content', (t) async {
      await t.pumpApp(
        Scaffold(
          body: MessageBubble(
            conversationId: 'c',
            message: tomb('me'),
            mine: true,
            myUid: 'me',
          ),
        ),
        overrides: overrides,
      );
      expect(
        find.textContaining('You deleted this message', findRichText: true),
        findsOneWidget,
      );
      await t.pumpApp(
        Scaffold(
          body: MessageBubble(
            conversationId: 'c',
            message: tomb('other'),
            mine: false,
            myUid: 'me',
          ),
        ),
        overrides: overrides,
      );
      expect(
        find.textContaining('This message was deleted', findRichText: true),
        findsOneWidget,
      );
    });
  });

  group('FailedBubble', () {
    testWidgets('offers retry and remove for transient failures', (t) async {
      var retried = false, removed = false;
      await t.pumpApp(
        Scaffold(
          body: FailedBubble(
            failed: FailedMessage(
              id: '1',
              text: 'oops',
              failure: const NetworkFailure(),
              createdAt: DateTime(2026),
            ),
            onRetry: () => retried = true,
            onDiscard: () => removed = true,
          ),
        ),
      );
      expect(find.text('oops'), findsOneWidget);
      await t.tap(find.text('Try again'));
      await t.tap(find.text('Remove'));
      expect(retried && removed, isTrue);
    });

    testWidgets('hides retry for permission failures (security outcome)', (
      t,
    ) async {
      await t.pumpApp(
        Scaffold(
          body: FailedBubble(
            failed: FailedMessage(
              id: '1',
              text: 'x',
              failure: const PermissionFailure(),
              createdAt: DateTime(2026),
            ),
            onRetry: () {},
            onDiscard: () {},
          ),
        ),
      );
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Remove'), findsOneWidget);
    });
  });

  group('State views', () {
    testWidgets('ErrorState shows localized copy, never raw error text', (
      t,
    ) async {
      await t.pumpApp(
        const Scaffold(body: ErrorState(error: 'SECRET raw firebase text')),
      );
      expect(find.textContaining('SECRET'), findsNothing);
      expect(find.textContaining('Reference:'), findsOneWidget);
    });

    testWidgets('ErrorState retry hidden for permission errors', (t) async {
      await t.pumpApp(
        Scaffold(
          body: ErrorState(error: const PermissionFailure(), onRetry: () {}),
        ),
      );
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('ErrorState offers retry for network errors', (t) async {
      var n = 0;
      await t.pumpApp(
        Scaffold(
          body: ErrorState(error: const NetworkFailure(), onRetry: () => n++),
        ),
      );
      await t.tap(find.text('Try again'));
      expect(n, 1);
    });

    testWidgets('EmptyState renders action', (t) async {
      var tapped = false;
      await t.pumpApp(
        Scaffold(
          body: EmptyState(
            icon: Icons.chat,
            title: 'T',
            message: 'M',
            actionLabel: 'Go',
            onAction: () => tapped = true,
          ),
        ),
      );
      await t.tap(find.text('Go'));
      expect(tapped, isTrue);
    });
  });

  group('AuthScreen', () {
    testWidgets('validates email and password before calling the backend', (
      t,
    ) async {
      final auth = _FakeAuth();
      await t.pumpApp(
        const AuthScreen(initialMode: AuthMode.login),
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
      );
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await t.pump();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(auth.calls, isEmpty);

      await t.enterText(find.byType(TextFormField).first, 'a@b.co');
      await t.enterText(find.byType(TextFormField).last, 'short');
      await t.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await t.pump();
      expect(
        find.text('Use a password with at least 8 characters.'),
        findsOneWidget,
      );
      expect(auth.calls, isEmpty);
    });

    testWidgets(
      'submits valid credentials and shows a localized error on failure',
      (t) async {
        final auth =
            _FakeAuth()
              ..error = const AuthFailure(AuthReason.invalidCredentials);
        await t.pumpApp(
          const AuthScreen(initialMode: AuthMode.login),
          overrides: [authRepositoryProvider.overrideWithValue(auth)],
        );
        await t.pump();
        await t.enterText(find.byType(TextFormField).first, 'a@b.co');
        await t.enterText(find.byType(TextFormField).last, 'longenough1');
        await t.tap(find.widgetWithText(FilledButton, 'Sign in'));
        await t.pumpAndSettle();
        expect(auth.calls, ['signIn:a@b.co']);
        expect(
          find.text("That email or password isn't right."),
          findsOneWidget,
        );
      },
    );

    testWidgets('password visibility toggle works', (t) async {
      await t.pumpApp(
        const AuthScreen(initialMode: AuthMode.login),
        overrides: [authRepositoryProvider.overrideWithValue(_FakeAuth())],
      );
      await t.pump();
      EditableText field() =>
          t.widget<EditableText>(find.byType(EditableText).last);
      expect(field().obscureText, isTrue);
      await t.tap(find.byTooltip('Show password'));
      await t.pump();
      expect(field().obscureText, isFalse);
    });

    testWidgets(
      'Google button is shown (Google is configured for this project)',
      (t) async {
        await t.pumpApp(
          const AuthScreen(),
          overrides: [authRepositoryProvider.overrideWithValue(_FakeAuth())],
        );
        await t.pump();
        expect(find.text('Continue with Google'), findsOneWidget);
        expect(
          find.text('Continue with Apple'),
          findsNothing,
        ); // Apple is opt-in
      },
    );
  });
}
