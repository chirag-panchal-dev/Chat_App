import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/validators.dart';
import '../../../attachments/presentation/viewmodels/attachment_providers.dart';
import '../../../auth/presentation/viewmodels/auth_providers.dart';
import 'profile_providers.dart';

enum UsernameStatus { idle, invalid, checking, available, taken, error }

class ProfileSetupState {
  const ProfileSetupState({
    this.username = UsernameStatus.idle,
    this.busy = false,
    this.failure,
    this.avatar,
  });

  final UsernameStatus username;
  final bool busy;
  final Failure? failure;
  final File? avatar;

  ProfileSetupState copyWith({
    UsernameStatus? username,
    bool? busy,
    Object? failure = _keep,
    Object? avatar = _keep,
  }) => ProfileSetupState(
    username: username ?? this.username,
    busy: busy ?? this.busy,
    failure: identical(failure, _keep) ? this.failure : failure as Failure?,
    avatar: identical(avatar, _keep) ? this.avatar : avatar as File?,
  );

  static const _keep = Object();
}

class ProfileSetupViewModel extends Notifier<ProfileSetupState> {
  Timer? _debounce;
  int _token = 0;

  @override
  ProfileSetupState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const ProfileSetupState();
  }

  /// Debounced live availability check; the authoritative check is the
  /// transaction in [submit].
  void usernameChanged(String raw) {
    _debounce?.cancel();
    final name = Usernames.normalize(raw);
    if (name.isEmpty) {
      state = state.copyWith(username: UsernameStatus.idle);
      return;
    }
    if (!Usernames.isValid(name)) {
      state = state.copyWith(username: UsernameStatus.invalid);
      return;
    }
    state = state.copyWith(username: UsernameStatus.checking);
    final token = ++_token;
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final free = await ref
            .read(profileRepositoryProvider)
            .isUsernameAvailable(name);
        if (token != _token) return;
        state = state.copyWith(
          username: free ? UsernameStatus.available : UsernameStatus.taken,
        );
      } catch (_) {
        if (token == _token) {
          state = state.copyWith(username: UsernameStatus.error);
        }
      }
    });
  }

  void setAvatar(File? f) => state = state.copyWith(avatar: f);

  /// Returns true on success.
  Future<bool> submit({
    required String username,
    required String displayName,
    String? bio,
  }) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return false;
    state = state.copyWith(busy: true, failure: null);
    try {
      final name = Usernames.require(username);
      if (!FieldValidators.isValidDisplayName(displayName)) {
        throw const ValidationFailure(ValidationReason.displayNameInvalid);
      }
      final repo = ref.read(profileRepositoryProvider);
      String? photoPath;
      final avatar = state.avatar;
      if (avatar != null) {
        final processed = await ref
            .read(imageProcessorProvider)
            .processAvatar(avatar);
        photoPath = await repo.uploadAvatar(uid, processed);
      }
      await repo.createProfile(
        uid: uid,
        username: name,
        displayName: displayName,
        bio: bio,
        photoPath: photoPath,
      );
      state = state.copyWith(busy: false);
      return true;
    } catch (e) {
      final f = Failure.from(e);
      state = state.copyWith(
        busy: false,
        failure: f,
        username:
            f is ValidationFailure && f.reason == ValidationReason.usernameTaken
                ? UsernameStatus.taken
                : state.username,
      );
      return false;
    }
  }
}

final profileSetupViewModelProvider =
    NotifierProvider.autoDispose<ProfileSetupViewModel, ProfileSetupState>(
      ProfileSetupViewModel.new,
    );
