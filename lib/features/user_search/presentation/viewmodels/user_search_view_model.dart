import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/presentation/viewmodels/auth_providers.dart';
import '../../../conversations/presentation/viewmodels/conversation_providers.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../../profile/presentation/viewmodels/profile_providers.dart';
import '../../domain/start_direct_conversation_use_case.dart';

enum SearchPhase { idle, searching, found, notFound, isSelf, error }

class UserSearchState {
  const UserSearchState({
    this.phase = SearchPhase.idle,
    this.result,
    this.failure,
    this.starting = false,
  });

  final SearchPhase phase;
  final Profile? result;
  final Failure? failure;
  final bool starting;
}

/// Explicit exact-username lookup. There is intentionally no directory
/// listing or prefix search (prevents scraping; rules deny `list`).
class UserSearchViewModel extends Notifier<UserSearchState> {
  @override
  UserSearchState build() => const UserSearchState();

  Future<void> search(String raw) async {
    final name = Usernames.normalize(raw);
    if (name.isEmpty) {
      state = const UserSearchState();
      return;
    }
    if (!Usernames.isValid(name)) {
      state = const UserSearchState(phase: SearchPhase.notFound);
      return;
    }
    state = const UserSearchState(phase: SearchPhase.searching);
    try {
      final p = await ref.read(profileRepositoryProvider).findByUsername(name);
      final me = ref.read(currentUidProvider);
      if (p == null) {
        state = const UserSearchState(phase: SearchPhase.notFound);
      } else if (p.uid == me) {
        state = const UserSearchState(phase: SearchPhase.isSelf);
      } else {
        state = UserSearchState(phase: SearchPhase.found, result: p);
      }
    } catch (e) {
      state = UserSearchState(
        phase: SearchPhase.error,
        failure: Failure.from(e),
      );
    }
  }

  /// Returns the conversation id, or null on failure (state carries error).
  Future<String?> message() async {
    final me = ref.read(currentUidProvider);
    final other = state.result;
    if (me == null || other == null) return null;
    state = UserSearchState(
      phase: SearchPhase.found,
      result: other,
      starting: true,
    );
    try {
      final id = await StartDirectConversationUseCase(
        ref.read(conversationRepositoryProvider),
      ).call(me: me, otherUid: other.uid);
      state = UserSearchState(phase: SearchPhase.found, result: other);
      return id;
    } catch (e) {
      state = UserSearchState(
        phase: SearchPhase.error,
        failure: Failure.from(e),
        result: other,
      );
      return null;
    }
  }
}

final userSearchViewModelProvider =
    NotifierProvider.autoDispose<UserSearchViewModel, UserSearchState>(
      UserSearchViewModel.new,
    );
