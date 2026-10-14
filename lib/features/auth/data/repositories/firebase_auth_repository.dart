import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/failure.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;
  final _reloads = StreamController<void>.broadcast();
  bool _googleReady = false;

  AppUser? _map(User? u) =>
      u == null
          ? null
          : AppUser(
            uid: u.uid,
            email: u.email,
            emailVerified: u.emailVerified,
            providerIds: u.providerData.map((p) => p.providerId).toList(),
          );

  @override
  Stream<AppUser?> authState() async* {
    yield _map(_auth.currentUser);
    final merged = StreamController<AppUser?>();
    final subs = <StreamSubscription<dynamic>>[
      _auth.userChanges().listen((u) => merged.add(_map(u))),
      _reloads.stream.listen((_) => merged.add(_map(_auth.currentUser))),
    ];
    merged.onCancel = () async {
      for (final s in subs) {
        await s.cancel();
      }
    };
    yield* merged.stream;
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
  Future<void> signUpWithEmail(String email, String password) =>
      _guard(() async {
        final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        await cred.user?.sendEmailVerification();
      });

  @override
  Future<void> signInWithEmail(String email, String password) => _guard(
    () => _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );

  @override
  Future<void> sendEmailVerification() =>
      _guard(() async => _auth.currentUser?.sendEmailVerification());

  @override
  Future<void> reloadUser() => _guard(() async {
    await _auth.currentUser?.reload();
    _reloads.add(null);
  });

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> signOut() => _guard(() async {
    if (_googleReady) await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  });

  Future<OAuthCredential> _googleCredential() async {
    final g = GoogleSignIn.instance;
    if (!_googleReady) {
      await g.initialize(
        serverClientId:
            AppConfig.googleServerClientId.isEmpty
                ? null
                : AppConfig.googleServerClientId,
      );
      _googleReady = true;
    }
    try {
      final account = await g.authenticate();
      final idToken = account.authentication.idToken;
      return GoogleAuthProvider.credential(idToken: idToken);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthFailure(AuthReason.cancelled);
      }
      throw const AuthFailure(AuthReason.other);
    }
  }

  @override
  Future<void> signInWithGoogle() => _guard(() async {
    final cred = await _googleCredential();
    await _auth.signInWithCredential(cred);
  });

  static String _nonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final r = Random.secure();
    return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<OAuthCredential> _appleCredential() async {
    final raw = _nonce();
    final hashed = sha256.convert(utf8.encode(raw)).toString();
    try {
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashed,
      );
      return OAuthProvider('apple.com').credential(
        idToken: apple.identityToken,
        rawNonce: raw,
        accessToken: apple.authorizationCode,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const AuthFailure(AuthReason.cancelled);
      }
      throw const AuthFailure(AuthReason.other);
    }
  }

  @override
  Future<void> signInWithApple() => _guard(() async {
    final cred = await _appleCredential();
    await _auth.signInWithCredential(cred);
  });

  @override
  Future<void> reauthenticateWithPassword(String password) => _guard(() async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthFailure(AuthReason.reauthRequired);
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
  });

  @override
  Future<void> reauthenticateWithProvider() => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure(AuthReason.reauthRequired);
    final ids = user.providerData.map((p) => p.providerId);
    final cred =
        ids.contains('apple.com')
            ? await _appleCredential()
            : await _googleCredential();
    await user.reauthenticateWithCredential(cred);
  });
}
