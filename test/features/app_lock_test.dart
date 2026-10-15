import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hushlo/features/app_lock/domain/app_lock_authenticator.dart';
import 'package:hushlo/features/app_lock/domain/app_lock_models.dart';
import 'package:hushlo/features/app_lock/presentation/app_lock_controller.dart';
import 'package:hushlo/features/app_lock/presentation/app_lock_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/pump_app.dart';

class FakeAuthenticator implements AppLockAuthenticator {
  bool available = true;
  AuthOutcome outcome = AuthOutcome.success;
  int prompts = 0;
  String? lastReason;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<AuthOutcome> authenticate(String reason) async {
    prompts++;
    lastReason = reason;
    return outcome;
  }
}

void main() {
  late FakeAuthenticator auth;
  late DateTime clock;

  Future<ProviderContainer> make({Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    final sp = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        appLockAuthenticatorProvider.overrideWithValue(auth),
      ],
    );
    c.listen(appLockProvider, (_, __) {});
    return c;
  }

  AppLockController ctl(ProviderContainer c) =>
      c.read(appLockProvider.notifier);
  AppLockState st(ProviderContainer c) => c.read(appLockProvider);

  setUp(() {
    auth = FakeAuthenticator();
    clock = DateTime(2026, 1, 1, 12);
    AppLockController.now = () => clock;
  });
  tearDown(() => AppLockController.now = DateTime.now);

  group('shouldLockOnResume', () {
    final t0 = DateTime(2026, 1, 1, 12);
    test('never when disabled or when the app was not backgrounded', () {
      expect(
        shouldLockOnResume(
          enabled: false,
          leftAt: t0,
          now: t0.add(const Duration(hours: 5)),
          timeout: Duration.zero,
        ),
        isFalse,
      );
      expect(
        shouldLockOnResume(
          enabled: true,
          leftAt: null,
          now: t0,
          timeout: Duration.zero,
        ),
        isFalse,
      );
    });
    test('locks once the timeout has elapsed', () {
      const one = Duration(minutes: 1);
      expect(
        shouldLockOnResume(
          enabled: true,
          leftAt: t0,
          now: t0.add(const Duration(seconds: 59)),
          timeout: one,
        ),
        isFalse,
      );
      expect(
        shouldLockOnResume(
          enabled: true,
          leftAt: t0,
          now: t0.add(one),
          timeout: one,
        ),
        isTrue,
      );
      expect(
        shouldLockOnResume(
          enabled: true,
          leftAt: t0,
          now: t0,
          timeout: Duration.zero,
        ),
        isTrue,
      );
    });
  });

  group('AppLockController', () {
    test('cold start: locked when enabled, open when disabled', () async {
      final off = await make();
      expect(st(off).locked, isFalse);
      off.dispose();
      final on = await make(prefs: {'applock.enabled': true});
      expect(st(on).locked, isTrue);
      on.dispose();
    });

    test('defaults: 1 minute delay, preview cover on', () async {
      final c = await make();
      addTearDown(c.dispose);
      expect(st(c).settings.timeout, AppLockTimeout.oneMinute);
      expect(st(c).settings.hidePreview, isTrue);
    });

    test('short trips in the background do not lock', () async {
      final c = await make(
        prefs: {'applock.enabled': true, 'applock.timeout': 'oneMinute'},
      );
      addTearDown(c.dispose);
      await ctl(c).unlock();
      expect(st(c).locked, isFalse);
      ctl(c).didChangeAppLifecycleState(AppLifecycleState.paused);
      clock = clock.add(const Duration(seconds: 30));
      ctl(c).didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(st(c).locked, isFalse);
    });

    test('locks after the chosen delay', () async {
      final c = await make(
        prefs: {'applock.enabled': true, 'applock.timeout': 'fiveMinutes'},
      );
      addTearDown(c.dispose);
      await ctl(c).unlock();
      ctl(c).didChangeAppLifecycleState(AppLifecycleState.paused);
      clock = clock.add(const Duration(minutes: 6));
      ctl(c).didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(st(c).locked, isTrue);
    });

    test('"immediately" locks on every return', () async {
      final c = await make(
        prefs: {'applock.enabled': true, 'applock.timeout': 'immediately'},
      );
      addTearDown(c.dispose);
      await ctl(c).unlock();
      ctl(c).didChangeAppLifecycleState(AppLifecycleState.paused);
      ctl(c).didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(st(c).locked, isTrue);
    });

    test(
      'inactive (app switcher) covers the UI only while the lock is on',
      () async {
        final c = await make(prefs: {'applock.enabled': true});
        addTearDown(c.dispose);
        await ctl(c).unlock();
        ctl(c).didChangeAppLifecycleState(AppLifecycleState.inactive);
        expect(st(c).obscured, isTrue);
        ctl(c).didChangeAppLifecycleState(AppLifecycleState.resumed);
        expect(st(c).obscured, isFalse);
        expect(st(c).locked, isFalse, reason: 'inactive alone must not lock');

        await ctl(c).setHidePreview(false);
        ctl(c).didChangeAppLifecycleState(AppLifecycleState.inactive);
        expect(st(c).obscured, isFalse);
      },
    );

    test('no cover when the lock is off', () async {
      final c = await make();
      addTearDown(c.dispose);
      ctl(c).didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(st(c).obscured, isFalse);
    });

    test('lifecycle events caused by the system prompt are ignored', () async {
      final c = await make(
        prefs: {'applock.enabled': true, 'applock.timeout': 'immediately'},
      );
      addTearDown(c.dispose);
      // Simulate the prompt pausing/resuming the app while authenticating.
      final slow = FakeAuthenticator();
      expect(slow.prompts, 0);
      final unlocking = ctl(c).unlock();
      expect(st(c).authenticating, isTrue);
      ctl(c).didChangeAppLifecycleState(AppLifecycleState.paused);
      ctl(c).didChangeAppLifecycleState(AppLifecycleState.resumed);
      await unlocking;
      expect(
        st(c).locked,
        isFalse,
        reason: 'unlock succeeded and was not re-locked',
      );
    });

    test(
      'unlock success opens the app; failure keeps it locked with the reason',
      () async {
        final c = await make(prefs: {'applock.enabled': true});
        addTearDown(c.dispose);
        auth.outcome = AuthOutcome.failed;
        await ctl(c).unlock();
        expect(st(c).locked, isTrue);
        expect(st(c).lastOutcome, AuthOutcome.failed);
        auth.outcome = AuthOutcome.success;
        await ctl(c).unlock();
        expect(st(c).locked, isFalse);
        expect(auth.prompts, 2);
      },
    );

    test(
      'turning the lock ON needs a screen lock and a successful check',
      () async {
        final c = await make();
        addTearDown(c.dispose);
        auth.available = false;
        expect(
          await ctl(c).setEnabled(true, reason: 'r'),
          LockChange.notAvailable,
        );
        expect(auth.prompts, 0);
        expect(st(c).settings.enabled, isFalse);

        auth.available = true;
        auth.outcome = AuthOutcome.cancelled;
        expect(
          await ctl(c).setEnabled(true, reason: 'confirm'),
          LockChange.failed,
        );
        expect(
          st(c).settings.enabled,
          isFalse,
          reason: 'not persisted when verification fails',
        );

        auth.outcome = AuthOutcome.success;
        expect(
          await ctl(c).setEnabled(true, reason: 'confirm'),
          LockChange.done,
        );
        expect(st(c).settings.enabled, isTrue);
        expect(auth.lastReason, 'confirm');
      },
    );

    test('turning it OFF also needs authentication', () async {
      final c = await make(prefs: {'applock.enabled': true});
      addTearDown(c.dispose);
      auth.outcome = AuthOutcome.failed;
      expect(await ctl(c).setEnabled(false, reason: 'r'), LockChange.failed);
      expect(st(c).settings.enabled, isTrue);
      auth.outcome = AuthOutcome.success;
      expect(await ctl(c).setEnabled(false, reason: 'r'), LockChange.done);
      expect(st(c).settings.enabled, isFalse);
      expect(st(c).locked, isFalse);
    });

    test('settings persist across restarts', () async {
      final c1 = await make();
      await ctl(c1).setEnabled(true, reason: 'r');
      await ctl(c1).setTimeout(AppLockTimeout.fifteenMinutes);
      await ctl(c1).setHidePreview(false);
      final sp = await SharedPreferences.getInstance();
      c1.dispose();

      final c2 = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sp),
          appLockAuthenticatorProvider.overrideWithValue(auth),
        ],
      );
      addTearDown(c2.dispose);
      c2.listen(appLockProvider, (_, __) {});
      expect(st(c2).settings.enabled, isTrue);
      expect(st(c2).settings.timeout, AppLockTimeout.fifteenMinutes);
      expect(st(c2).settings.hidePreview, isFalse);
      expect(st(c2).locked, isTrue, reason: 'locked on the next cold start');
    });
  });

  group('AppLockGate', () {
    const app = AppLockGate(child: Center(child: Text('secret chats')));

    Future<List<Override>> overrides(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      final sp = await SharedPreferences.getInstance();
      return [
        sharedPreferencesProvider.overrideWithValue(sp),
        appLockAuthenticatorProvider.overrideWithValue(auth),
      ];
    }

    testWidgets('shows the lock screen over the app while locked', (t) async {
      auth.outcome = AuthOutcome.failed; // keep it locked after the auto-prompt
      await t.pumpApp(
        app,
        overrides: await overrides({'applock.enabled': true}),
      );
      await t.pumpAndSettle();
      expect(find.text('Hushlo is locked'), findsOneWidget);
      expect(find.text('Unlock'), findsOneWidget);
      expect(
        auth.prompts,
        1,
        reason: 'prompts automatically on a locked start',
      );
      // Content is inert and hidden from accessibility while locked.
      expect(find.bySemanticsLabel('secret chats'), findsNothing);
    });

    testWidgets('tapping Unlock re-prompts and then reveals the app', (
      t,
    ) async {
      auth.outcome = AuthOutcome.failed;
      await t.pumpApp(
        app,
        overrides: await overrides({'applock.enabled': true}),
      );
      await t.pumpAndSettle();
      auth.outcome = AuthOutcome.success;
      await t.tap(find.text('Unlock'));
      await t.pumpAndSettle();
      expect(find.text('Hushlo is locked'), findsNothing);
      expect(find.bySemanticsLabel('secret chats'), findsOneWidget);
    });

    testWidgets('no lock screen when App lock is off', (t) async {
      await t.pumpApp(app, overrides: await overrides(const {}));
      await t.pumpAndSettle();
      expect(find.text('Hushlo is locked'), findsNothing);
      expect(auth.prompts, 0);
    });
  });
}
