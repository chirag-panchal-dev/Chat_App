import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/viewmodels/auth_providers.dart';
import '../../data/firestore_settings_repository.dart';
import '../../domain/privacy_settings.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => FirestoreSettingsRepository(ref.watch(firestoreProvider)),
);

final settingsProvider = StreamProvider<PrivacySettings>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const PrivacySettings());
  return ref.watch(settingsRepositoryProvider).watchSettings(uid);
});

/// Theme mode derived from synced settings; falls back to system.
final themeModeProvider = Provider<ThemeMode>(
  (ref) => ref.watch(settingsProvider).value?.themeMode ?? ThemeMode.system,
);
