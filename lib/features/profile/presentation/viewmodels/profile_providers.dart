import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/viewmodels/auth_providers.dart';
import '../../data/firestore_profile_repository.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => FirestoreProfileRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseStorageProvider),
  ),
);

/// The signed-in user's own profile. `null` data means "no profile yet"
/// (profile setup still required).
final currentProfileProvider = StreamProvider<Profile?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(profileRepositoryProvider).watchProfile(uid);
});

/// Another user's profile, cached for the session. `null` = deleted/unknown.
final profileByUidProvider = FutureProvider.family<Profile?, String>((
  ref,
  uid,
) {
  ref.keepAlive();
  return ref.watch(profileRepositoryProvider).getProfile(uid);
});
