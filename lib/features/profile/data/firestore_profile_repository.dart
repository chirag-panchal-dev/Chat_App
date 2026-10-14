import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/errors/failure.dart';
import '../domain/entities/profile.dart';
import '../domain/repositories/profile_repository.dart';

class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository(this._db, this._storage);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  DocumentReference<Map<String, dynamic>> _profile(String uid) =>
      _db.collection('publicProfiles').doc(uid);
  DocumentReference<Map<String, dynamic>> _index(String name) =>
      _db.collection('usernameIndex').doc(name);

  Profile? _map(DocumentSnapshot<Map<String, dynamic>> s) {
    final d = s.data();
    if (d == null) return null;
    final username = d['username'];
    final name = d['displayName'];
    if (username is! String || name is! String) return null; // invalid doc
    return Profile(
      uid: s.id,
      username: username,
      displayName: name,
      photoPath: d['photoPath'] as String?,
      bio: d['bio'] as String?,
    );
  }

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on Failure {
      rethrow;
    } catch (e) {
      throw Failure.from(e);
    }
  }

  @override
  Stream<Profile?> watchProfile(String uid) =>
      _profile(uid).snapshots().map(_map).handleError((Object e) {
        throw Failure.from(e);
      });

  @override
  Future<Profile?> getProfile(String uid) =>
      _guard(() async => _map(await _profile(uid).get()));

  @override
  Future<Profile?> findByUsername(String normalized) => _guard(() async {
    final idx = await _index(normalized).get();
    final uid = idx.data()?['uid'];
    if (uid is! String) return null;
    return _map(await _profile(uid).get());
  });

  @override
  Future<bool> isUsernameAvailable(String normalized) =>
      _guard(() async => !(await _index(normalized).get()).exists);

  @override
  Future<void> createProfile({
    required String uid,
    required String username,
    required String displayName,
    String? bio,
    String? photoPath,
  }) => _guard(() async {
    try {
      await _db.runTransaction((tx) async {
        final idx = _index(username);
        if ((await tx.get(idx)).exists) {
          throw const ValidationFailure(ValidationReason.usernameTaken);
        }
        tx.set(idx, {'uid': uid, 'createdAt': FieldValue.serverTimestamp()});
        tx.set(_profile(uid), {
          'uid': uid,
          'username': username,
          'usernameLower': username,
          'displayName': displayName.trim(),
          if (photoPath != null) 'photoPath': photoPath,
          if (bio != null && bio.trim().isNotEmpty) 'bio': bio.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.set(_db.doc('users/$uid/private/settings'), {
          'notificationEnabled': true,
          'showMessagePreview': false,
          'readReceiptsEnabled': true,
          'lastSeenVisibility': 'contacts_or_chat_members',
          'themeMode': 'system',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      // A rules rejection here means the index entry already exists.
      if (e.code == 'permission-denied' || e.code == 'aborted') {
        if (!await isUsernameAvailable(username)) {
          throw const ValidationFailure(ValidationReason.usernameTaken);
        }
      }
      rethrow;
    }
  });

  @override
  Future<void> updateProfile({
    required String uid,
    required String displayName,
    String? bio,
    String? photoPath,
  }) => _guard(() async {
    await _profile(uid).update({
      'displayName': displayName.trim(),
      'bio':
          (bio == null || bio.trim().isEmpty)
              ? FieldValue.delete()
              : bio.trim(),
      if (photoPath != null) 'photoPath': photoPath,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });

  @override
  Future<String> uploadAvatar(String uid, File file) => _guard(() async {
    final path =
        'avatars/$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _storage
        .ref(path)
        .putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return path;
  });
}
