import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../auth/presentation/viewmodels/auth_providers.dart';
import '../data/callable_account_deletion_repository.dart';
import '../domain/account_deletion_repository.dart';

final accountDeletionRepositoryProvider = Provider<AccountDeletionRepository>(
  (ref) => CallableAccountDeletionRepository(
    ref.watch(firebaseFunctionsProvider),
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  ),
);

enum DeletePhase { idle, working, needsReauth, failed }

class DeleteAccountState {
  const DeleteAccountState({this.phase = DeletePhase.idle, this.failure});
  final DeletePhase phase;
  final Failure? failure;
}

class DeleteAccountViewModel extends Notifier<DeleteAccountState> {
  DeletionReason? _reason;
  String? _details;
  bool _feedbackSent = false;

  @override
  DeleteAccountState build() => const DeleteAccountState();

  /// Deletes the account. Signs out only after the server accepted the
  /// deletion; asks for re-authentication when the backend requires it.
  Future<void> delete({DeletionReason? reason, String? details}) async {
    _reason = reason ?? _reason;
    _details = details ?? _details;
    state = const DeleteAccountState(phase: DeletePhase.working);
    try {
      final r = _reason;
      if (r != null && !_feedbackSent) {
        _feedbackSent = true;
        await ref
            .read(accountDeletionRepositoryProvider)
            .submitFeedback(r, _details);
      }
      await ref.read(accountDeletionRepositoryProvider).deleteAccount();
      await ref.read(authRepositoryProvider).signOut();
      state = const DeleteAccountState();
    } catch (e) {
      final f = Failure.from(e);
      if (f is AuthFailure && f.reason == AuthReason.reauthRequired) {
        state = const DeleteAccountState(phase: DeletePhase.needsReauth);
      } else {
        state = DeleteAccountState(phase: DeletePhase.failed, failure: f);
      }
    }
  }

  Future<void> reauthenticateAndDelete({String? password}) async {
    state = const DeleteAccountState(phase: DeletePhase.working);
    try {
      final auth = ref.read(authRepositoryProvider);
      if (password != null) {
        await auth.reauthenticateWithPassword(password);
      } else {
        await auth.reauthenticateWithProvider();
      }
    } catch (e) {
      final f = Failure.from(e);
      state =
          f is AuthFailure && f.reason == AuthReason.cancelled
              ? const DeleteAccountState(phase: DeletePhase.needsReauth)
              : DeleteAccountState(phase: DeletePhase.failed, failure: f);
      return;
    }
    await delete();
  }
}

final deleteAccountViewModelProvider =
    NotifierProvider.autoDispose<DeleteAccountViewModel, DeleteAccountState>(
      DeleteAccountViewModel.new,
    );
