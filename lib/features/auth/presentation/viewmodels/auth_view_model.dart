import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/validators.dart';
import 'auth_providers.dart';

enum AuthMode { login, signUp }

class AuthFormState {
  const AuthFormState({
    this.mode = AuthMode.login,
    this.busy = false,
    this.failure,
    this.resetSent = false,
  });

  final AuthMode mode;
  final bool busy;
  final Failure? failure;
  final bool resetSent;

  AuthFormState copyWith({
    AuthMode? mode,
    bool? busy,
    Object? failure = _keep,
    bool? resetSent,
  }) => AuthFormState(
    mode: mode ?? this.mode,
    busy: busy ?? this.busy,
    failure: identical(failure, _keep) ? this.failure : failure as Failure?,
    resetSent: resetSent ?? this.resetSent,
  );

  static const _keep = Object();
}

class AuthViewModel extends Notifier<AuthFormState> {
  AuthViewModel([AuthMode initial = AuthMode.login]) : _initial = initial;
  final AuthMode _initial;

  @override
  AuthFormState build() => AuthFormState(mode: _initial);

  void setMode(AuthMode m) =>
      state = AuthFormState(mode: m); // clears errors when switching

  Future<void> _run(Future<void> Function() action) async {
    state = state.copyWith(busy: true, failure: null, resetSent: false);
    try {
      await action();
      state = state.copyWith(busy: false);
    } catch (e) {
      final f = Failure.from(e);
      // A cancelled provider sheet is not an error worth showing.
      state = state.copyWith(
        busy: false,
        failure:
            f is AuthFailure && f.reason == AuthReason.cancelled ? null : f,
      );
    }
  }

  Future<void> submit(String email, String password) => _run(() {
    final repo = ref.read(authRepositoryProvider);
    return state.mode == AuthMode.login
        ? repo.signInWithEmail(email, password)
        : repo.signUpWithEmail(email, password);
  });

  Future<void> google() =>
      _run(() => ref.read(authRepositoryProvider).signInWithGoogle());

  Future<void> apple() =>
      _run(() => ref.read(authRepositoryProvider).signInWithApple());

  Future<void> resetPassword(String email) async {
    if (!FieldValidators.isEmail(email)) {
      state = state.copyWith(
        failure: const AuthFailure(AuthReason.invalidEmail),
        resetSent: false,
      );
      return;
    }
    await _run(() => ref.read(authRepositoryProvider).sendPasswordReset(email));
    if (state.failure == null) state = state.copyWith(resetSent: true);
  }
}

final authViewModelProvider =
    NotifierProvider.autoDispose<AuthViewModel, AuthFormState>(
      AuthViewModel.new,
    );
