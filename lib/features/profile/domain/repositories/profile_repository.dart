import 'dart:io';

import '../entities/profile.dart';

abstract interface class ProfileRepository {
  Stream<Profile?> watchProfile(String uid);
  Future<Profile?> getProfile(String uid);

  /// Exact username lookup (already normalized). Null when nobody has it.
  Future<Profile?> findByUsername(String normalizedUsername);

  Future<bool> isUsernameAvailable(String normalizedUsername);

  /// Atomically reserves the username and creates the profile plus default
  /// private settings. Throws `ValidationFailure(usernameTaken)` on a race.
  Future<void> createProfile({
    required String uid,
    required String username,
    required String displayName,
    String? bio,
    String? photoPath,
  });

  Future<void> updateProfile({
    required String uid,
    required String displayName,
    String? bio,
    String? photoPath,
  });

  /// Uploads an avatar and returns its Storage path.
  Future<String> uploadAvatar(String uid, File file);
}
