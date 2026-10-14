import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hushlo/core/errors/failure.dart';
import 'package:hushlo/features/account_deletion/domain/account_deletion_repository.dart';
import 'package:hushlo/features/account_deletion/presentation/delete_account_view_model.dart';
import 'package:hushlo/features/auth/domain/entities/app_user.dart';
import 'package:hushlo/features/auth/domain/repositories/auth_repository.dart';
import 'package:hushlo/features/auth/presentation/viewmodels/auth_providers.dart';

class _Deletion implements AccountDeletionRepository {
  final results = <Object?>[]; // null = success, otherwise thrown
  int calls = 0;
  final feedback = <String>[];
  @override
  Future<void> submitFeedback(DeletionReason r, String? d) async =>
      feedback.add(r.name);
  @override
  Future<void> deleteAccount() async {
    calls++;
    final r = results.isEmpty ? null : results.removeAt(0);
    if (r != null) throw r;
  }
}

class _Auth implements AuthRepository {
  final log = <String>[];
  Object? reauthError;
  @override
  Future<void> signOut() async => log.add('signOut');
  @override
  Future<void> reauthenticateWithPassword(String p) async {
    log.add('reauthPw');
    if (reauthError != null) throw reauthError!;
  }

  @override
  Future<void> reauthenticateWithProvider() async => log.add('reauthProvider');
  @override
  Stream<AppUser?> authState() => const Stream.empty();
  @override
  Future<void> signUpWithEmail(String e, String p) async {}
  @override
  Future<void> signInWithEmail(String e, String p) async {}
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signInWithApple() async {}
  @override
  Future<void> sendEmailVerification() async {}
  @override
  Future<void> reloadUser() async {}
  @override
  Future<void> sendPasswordReset(String e) async {}
}

void main() {
  late _Deletion del;
  late _Auth auth;
  late ProviderContainer c;

  setUp(() {
    del = _Deletion();
    auth = _Auth();
    c = ProviderContainer(
      overrides: [
        accountDeletionRepositoryProvider.overrideWithValue(del),
        authRepositoryProvider.overrideWithValue(auth),
      ],
    );
    c.listen(deleteAccountViewModelProvider, (_, __) {});
  });
  tearDown(() => c.dispose());

  DeleteAccountState s() => c.read(deleteAccountViewModelProvider);
  DeleteAccountViewModel vm() =>
      c.read(deleteAccountViewModelProvider.notifier);

  test('signs out only after the server accepted the deletion', () async {
    await vm().delete();
    expect(del.calls, 1);
    expect(auth.log, ['signOut']);
  });

  test('server failure does not sign the user out', () async {
    del.results.add(const NetworkFailure());
    await vm().delete();
    expect(auth.log, isEmpty);
    expect(s().phase, DeletePhase.failed);
  });

  test(
    'recent-login requirement asks for re-authentication, then deletes',
    () async {
      del.results.add(const AuthFailure(AuthReason.reauthRequired));
      await vm().delete();
      expect(s().phase, DeletePhase.needsReauth);
      expect(auth.log, isEmpty);

      await vm().reauthenticateAndDelete(password: 'pw');
      expect(auth.log, ['reauthPw', 'signOut']);
      expect(del.calls, 2);
    },
  );

  test('feedback is sent once, before deleting, even across reauth', () async {
    del.results.add(const AuthFailure(AuthReason.reauthRequired));
    await vm().delete(reason: DeletionReason.privacy, details: 'x');
    await vm().reauthenticateAndDelete(password: 'pw');
    expect(del.feedback, ['privacy']);
    expect(del.calls, 2);
  });

  test('no reason selected -> no feedback, deletion still works', () async {
    await vm().delete();
    expect(del.feedback, isEmpty);
    expect(del.calls, 1);
  });

  test('failed re-authentication does not delete anything', () async {
    del.results.add(const AuthFailure(AuthReason.reauthRequired));
    await vm().delete();
    auth.reauthError = const AuthFailure(AuthReason.invalidCredentials);
    await vm().reauthenticateAndDelete(password: 'bad');
    expect(del.calls, 1);
    expect(s().phase, DeletePhase.failed);
  });
}
