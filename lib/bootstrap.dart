import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/logging/app_log.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/app_lock/presentation/app_lock_controller.dart';
import 'features/notifications/data/local_notifications.dart';
import 'firebase_options.dart';
import 'setup_required_app.dart';

Future<void> bootstrap() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on UnsupportedError {
    // flutterfire configure has not been run yet.
    runApp(const SetupRequiredApp());
    return;
  }

  // Debug providers are used only outside release builds; release builds use
  // Play Integrity / App Attest. Enforcement is switched on in the console.
  await FirebaseAppCheck.instance.activate(
    androidProvider:
        kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
    appleProvider:
        kReleaseMode
            ? AppleProvider.appAttestWithDeviceCheckFallback
            : AppleProvider.debug,
  );

  if (AppConfig.useEmulator) {
    const authPort = 9099, firestorePort = 8080, storagePort = 9199;
    await FirebaseAuth.instance.useAuthEmulator(
      AppConfig.emulatorHost,
      authPort,
    );
    FirebaseFirestore.instance.useFirestoreEmulator(
      AppConfig.emulatorHost,
      firestorePort,
    );
    await FirebaseStorage.instance.useStorageEmulator(
      AppConfig.emulatorHost,
      storagePort,
    );
    AppLog.d('emulator.enabled');
  }

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 100 * 1024 * 1024,
  );

  final notifications = LocalNotifications();
  await notifications.init();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      // Permission-denied and similar errors must never be retried blindly.
      retry: (_, __) => null,
      overrides: [
        localNotificationsProvider.overrideWithValue(notifications),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const HushloApp(),
    ),
  );
}
