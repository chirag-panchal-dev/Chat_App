/// The signed-in account, independent of any Firebase type.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.emailVerified,
    required this.providerIds,
  });

  final String uid;
  final String? email;
  final bool emailVerified;
  final List<String> providerIds;

  bool get usesPassword => providerIds.contains('password');
  bool get usesGoogle => providerIds.contains('google.com');
  bool get usesApple => providerIds.contains('apple.com');

  /// Email/password accounts must verify their address before using the app.
  bool get needsEmailVerification => usesPassword && !emailVerified;
}
