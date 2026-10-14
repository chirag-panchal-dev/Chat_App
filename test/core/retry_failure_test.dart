import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hushlo/core/errors/failure.dart';
import 'package:hushlo/core/utils/retry.dart';

void main() {
  group('Failure.from', () {
    test('maps firestore codes', () {
      expect(
        Failure.from(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
        isA<PermissionFailure>(),
      );
      expect(
        Failure.from(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
        isA<NetworkFailure>(),
      );
    });
    test('maps auth codes without leaking raw text', () {
      final f = Failure.from(
        FirebaseAuthException(code: 'wrong-password', message: 'secret detail'),
      );
      expect(f, isA<AuthFailure>());
      expect((f as AuthFailure).reason, AuthReason.invalidCredentials);
    });
    test('unknown errors get a diagnostic id', () {
      final f = Failure.from(StateError('boom'));
      expect(f, isA<UnknownFailure>());
      expect((f as UnknownFailure).diagnosticId, isNotEmpty);
    });
    test('only network failures are transient', () {
      expect(const NetworkFailure().isTransient, isTrue);
      expect(const PermissionFailure().isTransient, isFalse);
      expect(
        const ValidationFailure(ValidationReason.other).isTransient,
        isFalse,
      );
    });
  });

  group('retryTransient', () {
    test('retries transient failures then succeeds', () async {
      var calls = 0;
      final r = await retryTransient(() async {
        if (++calls < 3) throw const NetworkFailure();
        return 'ok';
      }, sleep: (_) async {});
      expect(r, 'ok');
      expect(calls, 3);
    });
    test('does not retry permanent failures', () async {
      var calls = 0;
      await expectLater(
        retryTransient(() async {
          calls++;
          throw const PermissionFailure();
        }, sleep: (_) async {}),
        throwsA(isA<PermissionFailure>()),
      );
      expect(calls, 1);
    });
    test('gives up after maxAttempts', () async {
      var calls = 0;
      await expectLater(
        retryTransient(
          () async {
            calls++;
            throw const NetworkFailure();
          },
          maxAttempts: 2,
          sleep: (_) async {},
        ),
        throwsA(isA<NetworkFailure>()),
      );
      expect(calls, 2);
    });
  });
}
