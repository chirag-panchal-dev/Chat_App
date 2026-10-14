// Design-review harness: renders every main screen with realistic sample data
// (no Firebase) to PNGs, in light and dark.
//
//   SHOT_DIR=/some/dir flutter test tool/screenshots/screens_test.dart
//
// Not part of the normal test suite (lives in tool/, not test/).
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hushlo/core/theme/app_theme.dart';
import 'package:hushlo/core/utils/connectivity.dart';
import 'package:hushlo/features/auth/presentation/screens/auth_screen.dart';
import 'package:hushlo/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:hushlo/features/auth/presentation/viewmodels/auth_providers.dart';
import 'package:hushlo/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:hushlo/features/auth/domain/entities/app_user.dart';
import 'package:hushlo/features/chat/domain/entities/chat_message.dart';
import 'package:hushlo/features/chat/presentation/screens/chat_screen.dart';
import 'package:hushlo/features/chat/presentation/screens/contact_info_screen.dart';
import 'package:hushlo/features/chat/presentation/viewmodels/chat_view_model.dart';
import 'package:hushlo/features/conversations/domain/entities/conversation.dart';
import 'package:hushlo/features/conversations/presentation/screens/chats_screen.dart';
import 'package:hushlo/features/conversations/presentation/viewmodels/conversation_providers.dart';
import 'package:hushlo/features/notifications/presentation/push_controller.dart';
import 'package:hushlo/features/onboarding/presentation/intro_screen.dart';
import 'package:hushlo/features/presence/presentation/presence_controller.dart';
import 'package:hushlo/features/privacy_settings/domain/privacy_settings.dart';
import 'package:hushlo/features/privacy_settings/presentation/screens/settings_screen.dart';
import 'package:hushlo/features/privacy_settings/presentation/viewmodels/settings_providers.dart';
import 'package:hushlo/features/profile/domain/entities/profile.dart';
import 'package:hushlo/features/profile/presentation/screens/profile_setup_screen.dart';
import 'package:hushlo/features/profile/presentation/viewmodels/profile_providers.dart';
import 'package:hushlo/features/safety/presentation/viewmodels/safety_providers.dart';
import 'package:hushlo/features/user_search/presentation/screens/new_chat_screen.dart';
import 'package:hushlo/features/user_search/presentation/viewmodels/user_search_view_model.dart';
import 'package:hushlo/features/account_deletion/presentation/delete_account_screen.dart';
import 'package:hushlo/features/attachments/presentation/screens/attachment_preview_screen.dart';
import 'package:hushlo/l10n/app_localizations.dart';
import 'package:hushlo/core/firebase/media_url_provider.dart';
import '../../test/features/fakes.dart';

final _dir = Directory(Platform.environment['SHOT_DIR'] ?? '/tmp/hushlo_shots')
  ..createSync(recursive: true);

const _me = 'me';
const _people = {
  'aarav': Profile(
    uid: 'aarav',
    username: 'aarav',
    displayName: 'Aarav Sharma',
    bio: 'Product designer. Coffee, cricket and calm interfaces.',
  ),
  'meera': Profile(
    uid: 'meera',
    username: 'meera_p',
    displayName: 'Meera Patel',
    bio: 'Always up for a long walk.',
  ),
  'rohan': Profile(
    uid: 'rohan',
    username: 'rohan.m',
    displayName: 'Rohan Mehta',
  ),
  'ishita': Profile(
    uid: 'ishita',
    username: 'ishita_k',
    displayName: 'Ishita Kapoor',
  ),
  'dev': Profile(uid: 'dev', username: 'dev', displayName: 'Dev Team'),
};

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final l = FontLoader(family);
    for (final p in paths) {
      l.addFont(Future.value(ByteData.sublistView(File(p).readAsBytesSync())));
    }
    await l.load();
  }

  await load('Inter', [
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Medium.ttf',
    'assets/fonts/Inter-SemiBold.ttf',
    'assets/fonts/Inter-Bold.ttf',
  ]);
  final sdk =
      Platform.environment['FLUTTER_ROOT'] ??
      '${Platform.environment['HOME']}/development/flutter';
  await load('MaterialIcons', [
    '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

DateTime _t(int h, int m, {int daysAgo = 0}) {
  final n = DateTime.now().subtract(Duration(days: daysAgo));
  return DateTime(n.year, n.month, n.day, h, m);
}

ChatMessage _m(
  String id,
  String sender,
  DateTime at,
  String text, {
  SendStatus st = SendStatus.sent,
  String? reply,
  bool deleted = false,
  bool image = false,
}) => ChatMessage(
  id: id,
  senderId: sender,
  type: image ? MessageType.image : MessageType.text,
  createdAt: at,
  status: st,
  text: text,
  replyToId: reply,
  deleted: deleted,
  width: image ? 1200 : null,
  height: image ? 800 : null,
  mediaPath: image ? 'chatMedia/x/me/p.jpg' : null,
  thumbnailPath: image ? 'chatMedia/x/me/p_thumb.jpg' : null,
);

class _FakeSettingsRepo implements SettingsRepository {
  @override
  Stream<PrivacySettings> watchSettings(String uid) =>
      Stream.value(const PrivacySettings());
  @override
  Future<void> setNotificationEnabled(String uid, bool v) async {}
  @override
  Future<void> setShowMessagePreview(String uid, bool v) async {}
  @override
  Future<void> setReadReceipts(String uid, bool v) async {}
  @override
  Future<void> setShowLastSeen(String uid, bool v) async {}
  @override
  Future<void> setThemeMode(String uid, ThemeMode m) async {}
}

class _FakePush extends PushController {
  _FakePush(this.s);
  final PushState s;
  @override
  PushState build() => s;
}

class _FakeChatVM extends ChatViewModel {
  _FakeChatVM(super.cid, this.s);
  final ChatState s;
  @override
  ChatState build() => s;
}

class _FakeSearch extends UserSearchViewModel {
  _FakeSearch(this.s);
  final UserSearchState s;
  @override
  UserSearchState build() => s;
}

List<Override> _base({
  PushState push = const PushState(status: AuthorizationStatus.authorized),
}) => [
  currentUidProvider.overrideWithValue(_me),
  // Photos never resolve here: shows the loading placeholder in layout.
  mediaUrlProvider.overrideWith((ref, path) => Completer<String>().future),
  chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
  conversationRepositoryProvider.overrideWithValue(
    FakeConversationRepository(),
  ),
  settingsRepositoryProvider.overrideWithValue(_FakeSettingsRepo()),
  authStateProvider.overrideWith(
    (ref) => Stream.value(
      const AppUser(
        uid: _me,
        email: 'you@hushlo.app',
        emailVerified: true,
        providerIds: ['password'],
      ),
    ),
  ),
  currentProfileProvider.overrideWith(
    (ref) => Stream.value(
      const Profile(
        uid: _me,
        username: 'you',
        displayName: 'Nishu Bhardwaj',
        bio: 'Building calm things.',
      ),
    ),
  ),
  profileByUidProvider.overrideWith((ref, uid) async => _people[uid]),
  settingsProvider.overrideWith((ref) => Stream.value(const PrivacySettings())),
  isOnlineProvider.overrideWith((ref) => Stream.value(true)),
  blockedUidsProvider.overrideWith((ref) => Stream.value(const <String>{})),
  pushControllerProvider.overrideWith(
    () => _FakePush(PushState(status: push.status)),
  ),
  peerReceiptsProvider.overrideWith(
    (ref, k) => Stream.value(
      Receipts(
        lastDeliveredAt: DateTime.now(),
        lastReadAt: k.peer == 'aarav' ? DateTime.now() : null,
      ),
    ),
  ),
  peerPresenceProvider.overrideWith(
    (ref, uid) => Stream.value(uid == 'aarav' ? DateTime.now() : _t(17, 20)),
  ),
  presenceClockProvider.overrideWith((ref) => Stream.value(DateTime.now())),
  memberPrefsProvider.overrideWith(
    (ref, id) => Stream.value(
      MemberPrefs(
        pinned: id == 'aarav_me',
        lastReadAt: id == 'meera_me' ? _t(8, 0) : DateTime.now(),
      ),
    ),
  ),
  conversationProvider.overrideWith(
    (ref, id) => Stream.value(
      Conversation(id: id, memberIds: [id.split('_').first, _me]),
    ),
  ),
];

Inbox _inbox() {
  InboxItem it(
    String other,
    String text,
    DateTime at, {
    String sender = 'other',
    bool pinned = false,
    bool unread = false,
    bool image = false,
    bool deleted = false,
  }) => InboxItem(
    Conversation(id: '${other}_me', memberIds: [other, _me]),
    MemberPrefs(
      pinned: pinned,
      lastReadAt:
          unread
              ? at.subtract(const Duration(hours: 5))
              : at.add(const Duration(minutes: 1)),
    ),
    me: _me,
    lastMessage: InboxLastMessage(
      at: at,
      senderId: sender == 'other' ? other : _me,
      preview: text,
      isImage: image,
      deleted: deleted,
    ),
  );
  final items = [
    it(
      'aarav',
      'Sent you the final designs, check when free ✨',
      _t(17, 42),
      pinned: true,
      unread: true,
    ),
    it('meera', 'See you at 7 then!', _t(16, 10), sender: 'me'),
    it('rohan', 'Photo', _t(13, 5), image: true, unread: true),
    it(
      'ishita',
      'You deleted this message',
      _t(9, 31),
      sender: 'me',
      deleted: true,
    ),
    it('dev', 'Build 42 is live on TestFlight', _t(22, 0, daysAgo: 1)),
  ];
  return Inbox(active: sortInbox(items), archived: const []);
}

ChatState _chatState() {
  final msgs = <ChatMessage>[
    _m('9', 'me', _t(17, 44), 'Looks perfect 🙌', st: SendStatus.sent),
    _m('8', 'aarav', _t(17, 43), 'Let me know if you want any tweaks'),
    _m(
      '7',
      'aarav',
      _t(17, 42),
      'Sent you the final designs, check when free ✨',
    ),
    _m(
      '6',
      'me',
      _t(17, 40),
      'Hmm — can you share the dark mode one too?',
      reply: '4',
    ),
    _m('5', 'me', _t(17, 40), '', image: true),
    _m(
      '4',
      'aarav',
      _t(17, 38),
      'Here is the new onboarding flow. Three screens, no carousel.',
    ),
    _m('3', 'me', _t(17, 36), 'This message was removed', deleted: true),
    _m(
      '2',
      'me',
      _t(17, 30),
      'Morning! Did you get a chance to look at the brief?',
    ),
    _m('1', 'aarav', _t(9, 15, daysAgo: 1), 'Hey! Working on it now.'),
  ];
  return ChatState(latest: msgs, loading: false, hasMore: false);
}

Widget _app(Widget home, List<Override> overrides, ThemeMode mode) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        localizationsDelegates: const [
          AppL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppL10n.supportedLocales,
        home: home,
      ),
    );

final _boundary = GlobalKey();

Future<void> _shot(WidgetTester t, String name) async {
  await t.runAsync(() async {
    final b =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 3);
    final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!;
    File('${_dir.path}/$name.png').writeAsBytesSync(bytes.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  Future<void> run(
    WidgetTester t,
    String name,
    Widget screen,
    List<Override> o, {
    bool dark = false,
    Size size = const Size(390, 844),
  }) async {
    t.view.physicalSize = size * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      RepaintBoundary(
        key: _boundary,
        child: _app(screen, o, dark ? ThemeMode.dark : ThemeMode.light),
      ),
    );
    await t.runAsync(() async {
      final ctx = t.element(find.byType(MaterialApp));
      for (final a in const [
        'assets/illustrations/intro_hero.png',
        'assets/illustrations/empty_chats.png',
        'assets/illustrations/say_hello.png',
        'assets/illustrations/no_blocked.png',
        'assets/illustrations/chat_pattern.png',
        'assets/illustrations/verify_email.png',
        'assets/branding/hushlo_mark.png',
      ]) {
        await precacheImage(AssetImage(a), ctx);
      }
    });
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 600));
    await _shot(t, '${name}_${dark ? 'dark' : 'light'}');
  }

  for (final dark in [false, true]) {
    testWidgets('intro ${dark ? 'dark' : 'light'}', (t) async {
      await run(t, '01_intro', const IntroScreen(), [], dark: dark);
    });
    testWidgets('auth signup ${dark ? 'dark' : 'light'}', (t) async {
      await run(t, '02_auth', const AuthScreen(initialMode: AuthMode.signUp), [
        authViewModelProvider,
      ], dark: dark);
    });
    testWidgets('setup ${dark ? 'dark' : 'light'}', (t) async {
      await run(t, '03_setup', const ProfileSetupScreen(), _base(), dark: dark);
    });
    testWidgets('verify ${dark ? 'dark' : 'light'}', (t) async {
      await run(t, '04_verify', const VerifyEmailScreen(), _base(), dark: dark);
    });
    testWidgets('chats ${dark ? 'dark' : 'light'}', (t) async {
      await run(t, '05_chats', const ChatsScreen(), [
        ..._base(push: const PushState()),
        inboxProvider.overrideWithValue(AsyncValue.data(_inbox())),
      ], dark: dark);
    });
    testWidgets('chats typing ${dark ? 'dark' : 'light'}', (t) async {
      await run(t, '05b_chats_typing', const ChatsScreen(), [
        ..._base(),
        inboxProvider.overrideWithValue(AsyncValue.data(_inbox())),
        peerTypingProvider((
          cid: 'meera_me',
          peer: 'meera',
        )).overrideWith((ref) => Stream.value(DateTime.now())),
        typingClockProvider.overrideWith((ref) => Stream.value(DateTime.now())),
      ], dark: dark);
    });
    testWidgets('chat ${dark ? 'dark' : 'light'}', (t) async {
      await run(t, '06_chat', const ChatScreen(conversationId: 'aarav_me'), [
        ..._base(),
        chatViewModelProvider(
          'aarav_me',
        ).overrideWith(() => _FakeChatVM('aarav_me', _chatState())),
      ], dark: dark);
    });
    testWidgets('typing ${dark ? 'dark' : 'light'}', (t) async {
      await run(t, '06b_typing', const ChatScreen(conversationId: 'aarav_me'), [
        ..._base(),
        chatViewModelProvider(
          'aarav_me',
        ).overrideWith(() => _FakeChatVM('aarav_me', _chatState())),
        peerTypingProvider((
          cid: 'aarav_me',
          peer: 'aarav',
        )).overrideWith((ref) => Stream.value(DateTime.now())),
        typingClockProvider.overrideWith((ref) => Stream.value(DateTime.now())),
        reactionsProvider((cid: 'aarav_me', mid: '8')).overrideWith(
          (ref) => Stream.value({'aarav': '👍', 'me': '👍', 'x': '❤️'}),
        ),
      ], dark: dark);
    });
    testWidgets('chat menu ${dark ? 'dark' : 'light'}', (t) async {
      t.view.physicalSize = const Size(390, 844) * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(RepaintBoundary(
        key: _boundary,
        child: _app(const ChatScreen(conversationId: 'aarav_me'), [
          ..._base(),
          chatViewModelProvider('aarav_me').overrideWith(() => _FakeChatVM('aarav_me', _chatState())),
        ], dark ? ThemeMode.dark : ThemeMode.light),
      ));
      await t.pump(const Duration(milliseconds: 600));
      await t.tap(find.byTooltip('More options'));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('Clear chat'), findsOneWidget);
      await _shot(t, '06c_menu_${dark ? 'dark' : 'light'}');
    });
    testWidgets('contact info ${dark ? 'dark' : 'light'}', (t) async {
      await run(
        t,
        '07_contact',
        const ContactInfoScreen(conversationId: 'aarav_me'),
        [
          ..._base(),
          chatViewModelProvider(
            'aarav_me',
          ).overrideWith(() => _FakeChatVM('aarav_me', _chatState())),
        ],
        dark: dark,
      );
    });
    testWidgets('settings ${dark ? 'dark' : 'light'}', (t) async {
      await run(
        t,
        '08_settings',
        const SettingsScreen(),
        _base(),
        dark: dark,
        size: const Size(390, 1500),
      );
    });
    testWidgets('new chat ${dark ? 'dark' : 'light'}', (t) async {
      await run(t, '09_newchat', const NewChatScreen(), [
        ..._base(),
        userSearchViewModelProvider.overrideWith(
          () => _FakeSearch(
            UserSearchState(phase: SearchPhase.found, result: _people['meera']),
          ),
        ),
      ], dark: dark);
    });
    testWidgets('attachment ${dark ? 'dark' : 'light'}', (t) async {
      await run(
        t,
        '11_attachment',
        const AttachmentPreviewScreen(
          conversationId: 'aarav_me',
          path: 'assets/branding/icon_master.png',
        ),
        _base(),
        dark: dark,
      );
    });
    testWidgets('delete account ${dark ? 'dark' : 'light'}', (t) async {
      await run(
        t,
        '10_delete',
        const DeleteAccountScreen(),
        _base(),
        dark: dark,
        size: const Size(390, 1300),
      );
    });
  }
}
