import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/logging/app_log.dart';
import '../../auth/presentation/viewmodels/auth_providers.dart';
import '../../privacy_settings/presentation/viewmodels/settings_providers.dart';
import '../data/local_notifications.dart';
import '../data/push_service.dart';

final pushServiceProvider = Provider<PushService>(
  (ref) => PushService(
    ref.watch(firebaseMessagingProvider),
    ref.watch(firestoreProvider),
  ),
);

/// The conversation currently on screen (suppresses its foreground alerts).
class ActiveConversation extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? id) => state = id;
}

final activeConversationProvider =
    NotifierProvider<ActiveConversation, String?>(ActiveConversation.new);

/// A conversation to open once the user is signed in and set up.
class PendingConversation extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? id) => state = id;
}

final pendingConversationProvider =
    NotifierProvider<PendingConversation, String?>(PendingConversation.new);

class PushState {
  const PushState({this.status = AuthorizationStatus.notDetermined});
  final AuthorizationStatus status;

  bool get granted =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;
  bool get denied => status == AuthorizationStatus.denied;
  bool get canAsk => status == AuthorizationStatus.notDetermined;
}

class PushController extends Notifier<PushState> {
  final _subs = <StreamSubscription<dynamic>>[];

  @override
  PushState build() {
    ref.onDispose(() {
      for (final s in _subs) {
        s.cancel();
      }
      _subs.clear();
    });

    final uid = ref.watch(currentUidProvider);
    final service = ref.read(pushServiceProvider);
    final local = ref.read(localNotificationsProvider);

    Future<void>(() async {
      await service.configureForeground();
      await _refreshStatus();
      if (uid != null && state.granted) await _register(uid);
    });

    if (uid != null) {
      _subs.add(
        service.onTokenRefresh.listen((t) {
          service.refreshToken(uid, t).catchError((Object _) {});
        }),
      );
    }

    _subs.add(service.onForeground.listen((m) => _showForeground(m, local)));
    _subs.add(service.onOpened.listen((m) => _route(m.data['conversationId'])));
    _subs.add(local.taps.listen(_route));

    // Cold start from a notification tap.
    Future<void>(() async {
      final initial = await service.initialMessage();
      _route(initial?.data['conversationId'] ?? local.launchConversationId);
    });

    return const PushState();
  }

  void _route(Object? id) {
    if (id is String && id.isNotEmpty) {
      ref.read(pendingConversationProvider.notifier).set(id);
    }
  }

  void _showForeground(RemoteMessage m, LocalNotifications local) {
    final cid = m.data['conversationId'];
    if (cid is! String || cid == ref.read(activeConversationProvider)) return;
    final n = m.notification;
    if (n == null) return;
    local.show(
      id: cid.hashCode & 0x7fffffff,
      title: n.title ?? '',
      body: n.body ?? '',
      conversationId: cid,
      quiet:
          ref
              .read(settingsProvider)
              .value
              ?.quietHours
              .contains(DateTime.now()) ??
          false,
    );
  }

  Future<void> _refreshStatus() async {
    final s = await ref.read(pushServiceProvider).status();
    state = PushState(status: s);
  }

  Future<void> _register(String uid) async {
    // Respect the in-app switch: don't hold a token when notifications are off.
    final settings = ref.read(settingsProvider).value;
    if (settings != null && !settings.notificationEnabled) return;
    try {
      await ref.read(pushServiceProvider).registerDevice(uid);
    } catch (e) {
      AppLog.d('push.registerFailed');
    }
  }

  /// Called from an in-context prompt, after the benefit has been explained.
  Future<void> requestPermission() async {
    final s = await ref.read(pushServiceProvider).requestPermission();
    state = PushState(status: s);
    final uid = ref.read(currentUidProvider);
    if (state.granted && uid != null) await _register(uid);
  }

  Future<void> unregister() async {
    final uid = ref.read(currentUidProvider);
    if (uid != null) await ref.read(pushServiceProvider).unregisterDevice(uid);
  }

  Future<void> reRegister() async {
    await _refreshStatus();
    final uid = ref.read(currentUidProvider);
    if (state.granted && uid != null) await _register(uid);
  }
}

final pushControllerProvider = NotifierProvider<PushController, PushState>(
  PushController.new,
);
