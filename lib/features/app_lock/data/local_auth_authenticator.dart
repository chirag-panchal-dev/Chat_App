import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../domain/app_lock_authenticator.dart';
import '../domain/app_lock_models.dart';

/// Uses the system prompt: biometrics when enrolled, otherwise (or on
/// fallback) the device passcode/PIN/pattern. Hushlo never sees or stores any
/// biometric data or passcode.
class LocalAuthAuthenticator implements AppLockAuthenticator {
  LocalAuthAuthenticator([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();
  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AuthOutcome> authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow the device passcode as a fallback
          stickyAuth: true, // survive brief backgrounding during the prompt
        ),
      );
      return ok ? AuthOutcome.success : AuthOutcome.cancelled;
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'LockedOut':
        case 'PermanentlyLockedOut':
          return AuthOutcome.lockedOut;
        case 'NotAvailable':
        case 'NotEnrolled':
        case 'PasscodeNotSet':
          return AuthOutcome.notAvailable;
        default:
          return AuthOutcome.failed;
      }
    }
  }
}
