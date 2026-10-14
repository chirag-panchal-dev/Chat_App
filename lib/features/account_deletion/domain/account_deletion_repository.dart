/// Why the user is leaving. Names are stored verbatim in anonymous feedback
/// (and allow-listed by the security rules).
enum DeletionReason {
  anotherAccount,
  privacy,
  notUsing,
  notifications,
  betterApp,
  other,
}

abstract interface class AccountDeletionRepository {
  /// Stores anonymous leaving feedback (no uid, no email). Best effort.
  Future<void> submitFeedback(DeletionReason reason, String? details);

  /// Asks the trusted backend to delete the account and its data.
  /// Throws `AuthFailure(reauthRequired)` when a recent sign-in is needed.
  Future<void> deleteAccount();
}
