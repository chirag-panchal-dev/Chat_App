/// Build-time configuration. Values come from `--dart-define` so no
/// environment-specific data is hard-coded. See README for the full list.
abstract final class AppConfig {
  /// Shows the "Continue with Google" button. Turn on only once Google is
  /// enabled in Firebase Authentication and configured per platform.
  static const socialSignIn = bool.fromEnvironment(
    'SOCIAL_SIGN_IN',
    defaultValue: true,
  );

  /// Shows "Continue with Apple" on iOS. Needs a paid Apple Developer account
  /// and the Sign in with Apple capability. Apple's rules (4.8) require it
  /// before App Store release if Google sign-in is offered.
  static const appleSignIn = bool.fromEnvironment('APPLE_SIGN_IN');

  /// OAuth *web* client ID from the Firebase console, required by Google
  /// sign-in on Android.
  /// Public identifier (not a secret). Override with --dart-define for other
  /// Firebase projects.
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '284027131564-tsu8rbp3im5tbg72i7evp2k4o0155j6k.apps.googleusercontent.com',
  );

  /// Base URL of the hosted legal/deletion pages (no trailing slash).
  static const webBaseUrl = String.fromEnvironment('WEB_BASE_URL');

  /// Support contact shown in settings. Hidden when empty.
  static const supportEmail = String.fromEnvironment('SUPPORT_EMAIL');

  static const useEmulator = bool.fromEnvironment('USE_EMULATOR');
  static const emulatorHost = String.fromEnvironment(
    'EMULATOR_HOST',
    defaultValue: 'localhost',
  );

  /// Must match the region the Cloud Functions are deployed to.
  static const functionsRegion = String.fromEnvironment(
    'FUNCTIONS_REGION',
    defaultValue: 'us-central1',
  );

  // Product limits (mirrored in firestore.rules / storage.rules).
  static const maxMessageLength = 4000;
  static const maxCaptionLength = 1000;
  static const maxBioLength = 160;
  static const maxDisplayNameLength = 50;
  static const maxPickedImageBytes = 10 * 1024 * 1024;
  static const messagePageSize = 40;
  static const conversationLimit = 100;
}
