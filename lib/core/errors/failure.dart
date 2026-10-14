import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AuthReason {
  invalidCredentials,
  emailInUse,
  weakPassword,
  invalidEmail,
  userDisabled,
  tooManyRequests,
  accountExists,
  cancelled,
  reauthRequired,
  emailNotVerified,
  other,
}

enum ValidationReason {
  usernameInvalid,
  usernameTaken,
  displayNameInvalid,
  messageEmpty,
  messageTooLong,
  fileTooLarge,
  fileUnsupported,
  selfConversation,
  other,
}

/// Typed application failures. UI maps these to localized copy; raw Firebase
/// exception text is never shown to users.
sealed class Failure implements Exception {
  const Failure();

  /// Whether retrying the same operation may succeed.
  bool get isTransient => false;

  static Failure from(Object error) {
    if (error is Failure) return error;
    if (error is TimeoutException) return const NetworkFailure();
    if (error is FirebaseAuthException) return _auth(error);
    if (error is FirebaseFunctionsException) return _functions(error);
    if (error is FirebaseException) return _firebase(error);
    return UnknownFailure(diagnosticId(error));
  }

  static Failure _auth(FirebaseAuthException e) {
    final reason = switch (e.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' ||
      'invalid-login-credentials' => AuthReason.invalidCredentials,
      'email-already-in-use' => AuthReason.emailInUse,
      'weak-password' => AuthReason.weakPassword,
      'invalid-email' => AuthReason.invalidEmail,
      'user-disabled' => AuthReason.userDisabled,
      'too-many-requests' => AuthReason.tooManyRequests,
      'account-exists-with-different-credential' => AuthReason.accountExists,
      'requires-recent-login' => AuthReason.reauthRequired,
      'network-request-failed' => null,
      _ => AuthReason.other,
    };
    if (reason == null) return const NetworkFailure();
    return AuthFailure(reason);
  }

  static Failure _functions(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
      case 'failed-precondition':
        if ((e.message ?? '').contains('reauthentication-required')) {
          return const AuthFailure(AuthReason.reauthRequired);
        }
        return const PermissionFailure();
      case 'permission-denied':
        return const PermissionFailure();
      case 'unavailable':
      case 'deadline-exceeded':
        return const NetworkFailure();
      default:
        return UnknownFailure(diagnosticId(e));
    }
  }

  static Failure _firebase(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
      case 'unauthorized':
      case 'unauthenticated':
        return const PermissionFailure();
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
      case 'retry-limit-exceeded':
        return const NetworkFailure();
      case 'canceled':
        return const UploadFailure(UploadReason.cancelled);
      case 'quota-exceeded':
        return const UploadFailure(UploadReason.storage);
      default:
        if (e.plugin == 'firebase_storage') {
          return const UploadFailure(UploadReason.storage);
        }
        return UnknownFailure(diagnosticId(e));
    }
  }

  /// Short non-identifying id so a user can quote it to support without us
  /// logging payloads.
  static String diagnosticId(Object e) {
    final code = e is FirebaseException ? e.code : e.runtimeType.toString();
    final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    return '${code.hashCode.toUnsigned(20).toRadixString(36)}-$stamp';
  }
}

final class AuthFailure extends Failure {
  const AuthFailure(this.reason);
  final AuthReason reason;
}

final class NetworkFailure extends Failure {
  const NetworkFailure();
  @override
  bool get isTransient => true;
}

/// Firestore / Storage / Functions permission denied. Treated as a security
/// outcome: never retried automatically.
final class PermissionFailure extends Failure {
  const PermissionFailure();
}

final class ValidationFailure extends Failure {
  const ValidationFailure(this.reason);
  final ValidationReason reason;
}

enum UploadReason { tooLarge, unsupported, storage, cancelled }

final class UploadFailure extends Failure {
  const UploadFailure(this.reason);
  final UploadReason reason;
  @override
  bool get isTransient => reason == UploadReason.storage;
}

final class UnknownFailure extends Failure {
  const UnknownFailure(this.diagnosticId);
  final String diagnosticId;
}
