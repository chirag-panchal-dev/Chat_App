import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/viewmodels/auth_providers.dart';
import '../../data/firestore_safety_repository.dart';
import '../../domain/safety_repository.dart';

final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => FirestoreSafetyRepository(ref.watch(firestoreProvider)),
);

/// UIDs blocked by the current user. Drives immediate local UI updates.
final blockedUidsProvider = StreamProvider<Set<String>>((ref) {
  final me = ref.watch(currentUidProvider);
  if (me == null) return Stream.value(const {});
  return ref.watch(safetyRepositoryProvider).watchBlocked(me);
});
