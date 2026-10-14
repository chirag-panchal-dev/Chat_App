class Profile {
  const Profile({
    required this.uid,
    required this.username,
    required this.displayName,
    this.photoPath,
    this.bio,
  });

  final String uid;
  final String username;
  final String displayName;
  final String? photoPath;
  final String? bio;

  Profile copyWith({String? displayName, String? bio, String? photoPath}) =>
      Profile(
        uid: uid,
        username: username,
        displayName: displayName ?? this.displayName,
        photoPath: photoPath ?? this.photoPath,
        bio: bio ?? this.bio,
      );
}
