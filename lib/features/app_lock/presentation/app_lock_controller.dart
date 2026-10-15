import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_lock_store.dart';
import '../data/local_auth_authenticator.dart';
import '../domain/app_lock_authenticator.dart';
import '../domain/app_lock_models.dart';

/// Overridden in bootstrap with the loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('Overridden in bootstrap'),
);

final appLockAuthenticatorProvider = Provider<AppLockAuthenticator>(
  (_) => LocalAuthAuthenticator(),
);

final appLockStoreProvider = Provider<AppLockStore>(
  (ref) => AppLockStore(ref.watch(sharedPreferencesProvider)),
);

/// Whether the phone can authenticate (screen lock / biometrics set up).
final appLockAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(appLockAuthenticatorProvider).isAvailable(),
);

class AppLockState {
  const AppLockState({
    this.settings = const AppLockSettings(),
    this.locked = false,
    this.obscured = false,
    this.authenticating = false,
    this.lastOutcome,
  });

  final AppLockSettings settings;

  /// The app must be unlocked before it can be used.
  final bool locked;

  /// Cover the UI (app switcher / inactive) to hide chats from snapshots.
  final bool obscured;
  final bool authenticating;
  final AuthOutcome? lastOutcome;

  AppLockState copyWith({
    AppLockSettings? settings,
    bool? locked,
    bool? obscured,
    bool? authenticating,
    Object? lastOutcome = _keep,
  }) => AppLockState(
    settings: settings ?? this.settings,
    locked: locked ?? this.locked,
    obscured: obscured ?? this.obscured,
    authenticating: authenticating ?? this.authenticating,
    lastOutcome:
        identical(lastOutcome, _keep)
            ? this.lastOutcome
            : lastOutcome as AuthOutcome?,
  );

  static const _keep = Object();
}

/// Locks the app after it has been in the background for the chosen time and
/// on a cold start; covers the UI while it is inactive (app switcher).
class AppLockController extends Notifier<AppLockState>
    with WidgetsBindingObserver {
  DateTime? _leftAt;

  /// Injectable clock for tests.
  static DateTime Function() now = DateTime.now;

  /// Reason shown in the system prompt (set by the gate once localized).
  String unlockReason = 'Unlock Hushlo';

  AppLockAuthenticator get _auth => ref.read(appLockAuthenticatorProvider);
  AppLockStore get _store => ref.read(appLockStoreProvider);

  @override
  AppLockState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));
    final settings = _store.load();
    // Cold start: locked right away when the lock is on.
    return AppLockState(settings: settings, locked: settings.enabled);
  }

  @override
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    // The system prompt itself pauses/resumes the app: ignore those events.
    if (state.authenticating) return;
    final enabled = state.settings.enabled;
    switch (lifecycle) {
      case AppLifecycleState.inactive:
        if (enabled && state.settings.hidePreview) {
          state = state.copyWith(obscured: true);
        }
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _leftAt ??= now();
        if (enabled && state.settings.hidePreview && !state.obscured) {
          state = state.copyWith(obscured: true);
        }
      case AppLifecycleState.resumed:
        final lock = shouldLockOnResume(
          enabled: enabled,
          leftAt: _leftAt,
          now: now(),
          timeout: state.settings.timeout.duration,
        );
        _leftAt = null;
        state = state.copyWith(obscured: false, locked: state.locked || lock);
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Shows the system prompt; unlocks on success.
  Future<AuthOutcome?> unlock() async {
    if (!state.locked || state.authenticating) return null;
    state = state.copyWith(authenticating: true);
    final outcome = await _auth.authenticate(unlockReason);
    state = state.copyWith(
      authenticating: false,
      locked: outcome != AuthOutcome.success,
      lastOutcome: outcome,
    );
    return outcome;
  }

  /// Turning the lock on/off requires proving it's you first.
  Future<LockChange> setEnabled(bool value, {required String reason}) async {
    if (value == state.settings.enabled) return LockChange.done;
    if (value && !await _auth.isAvailable()) return LockChange.notAvailable;
    state = state.copyWith(authenticating: true);
    final outcome = await _auth.authenticate(reason);
    state = state.copyWith(authenticating: false);
    if (outcome == AuthOutcome.notAvailable) return LockChange.notAvailable;
    if (outcome != AuthOutcome.success) return LockChange.failed;
    await _persist(state.settings.copyWith(enabled: value));
    return LockChange.done;
  }

  Future<void> setTimeout(AppLockTimeout t) =>
      _persist(state.settings.copyWith(timeout: t));

  Future<void> setHidePreview(bool v) =>
      _persist(state.settings.copyWith(hidePreview: v));

  Future<void> _persist(AppLockSettings s) async {
    await _store.save(s);
    state = state.copyWith(
      settings: s,
      locked: s.enabled ? state.locked : false,
    );
  }
}

final appLockProvider = NotifierProvider<AppLockController, AppLockState>(
  AppLockController.new,
);
