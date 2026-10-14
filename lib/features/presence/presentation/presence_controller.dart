import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/presentation/viewmodels/auth_providers.dart';
import '../../privacy_settings/presentation/viewmodels/settings_providers.dart';
import '../data/presence_repository.dart';

final presenceRepositoryProvider = Provider<PresenceRepository>(
  (ref) => PresenceRepository(ref.watch(firestoreProvider)),
);

/// Another user's last-active time (null when they hide it / have none).
final peerPresenceProvider = StreamProvider.autoDispose
    .family<DateTime?, String>((ref, uid) {
      return ref.watch(presenceRepositoryProvider).watch(uid);
    });

/// Ticks every 30s so "online"/"last seen" labels refresh without new data.
final presenceClockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});

/// Publishes the signed-in user's presence while the app is in the
/// foreground (heartbeat) and stamps "last seen" when it backgrounds.
/// If the user turned "Last seen & online" off, nothing is written and any
/// existing presence doc is removed.
class PresenceController extends Notifier<void> with WidgetsBindingObserver {
  Timer? _timer;
  static const _heartbeat = Duration(seconds: 60);

  @override
  void build() {
    final me = ref.watch(currentUidProvider);
    final enabled = ref.watch(
      settingsProvider.select((s) => s.value?.showLastSeen),
    ); // null while loading
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _timer?.cancel();
    });
    if (me == null || enabled == null) return;
    if (enabled == false) {
      _timer?.cancel();
      ref.read(presenceRepositoryProvider).hide(me).catchError((Object _) {});
      return;
    }
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.detached) {
      _start(me);
    }
  }

  void _start(String me) {
    _beat(me);
    _timer?.cancel();
    _timer = Timer.periodic(_heartbeat, (_) => _beat(me));
  }

  void _beat(String me) =>
      ref.read(presenceRepositoryProvider).touch(me).catchError((Object _) {
        /* presence is best-effort */
      });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final me = ref.read(currentUidProvider);
    final enabled = ref.read(settingsProvider).value?.showLastSeen ?? false;
    if (me == null || !enabled) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _start(me);
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _timer?.cancel();
        _beat(me); // final "last seen" stamp
      default:
        break;
    }
  }
}

final presenceControllerProvider = NotifierProvider<PresenceController, void>(
  PresenceController.new,
);
