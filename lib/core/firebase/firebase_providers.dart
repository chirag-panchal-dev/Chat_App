import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

/// Firebase SDK instances are exposed only to the data layer. UI and
/// view-models depend on repositories, never on these providers.
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (_) => FirebaseAuth.instance,
);
final firestoreProvider = Provider<FirebaseFirestore>(
  (_) => FirebaseFirestore.instance,
);
final firebaseStorageProvider = Provider<FirebaseStorage>(
  (_) => FirebaseStorage.instance,
);
final firebaseMessagingProvider = Provider<FirebaseMessaging>(
  (_) => FirebaseMessaging.instance,
);
final firebaseFunctionsProvider = Provider<FirebaseFunctions>(
  (_) => FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion),
);
