import '../entities/app_user.dart';

abstract interface class AuthRepository {
  /// Emits the current user (or null) and every change, including reloads.
  Stream<AppUser?> authState();

  Future<void> signUpWithEmail(String email, String password);
  Future<void> signInWithEmail(String email, String password);
  Future<void> signInWithGoogle();
  Future<void> signInWithApple();
  Future<void> sendEmailVerification();

  /// Refreshes the user from the server (picks up email verification).
  Future<void> reloadUser();
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();

  /// Re-authenticates the current user with their password.
  Future<void> reauthenticateWithPassword(String password);

  /// Re-authenticates with whichever social provider the account uses.
  Future<void> reauthenticateWithProvider();
}
