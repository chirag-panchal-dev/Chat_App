import 'app_lock_models.dart';

/// Wraps the platform authentication (Face ID, fingerprint, device passcode).
abstract interface class AppLockAuthenticator {
  /// True when the phone has a screen lock or biometrics set up.
  Future<bool> isAvailable();

  Future<AuthOutcome> authenticate(String reason);
}
