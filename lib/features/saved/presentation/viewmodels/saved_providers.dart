import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/viewmodels/auth_providers.dart';
import '../../data/firestore_saved_repository.dart';
import '../../domain/saved_note.dart';
import '../../domain/saved_repository.dart';

final savedRepositoryProvider = Provider<SavedRepository>(
  (ref) => FirestoreSavedRepository(ref.watch(firestoreProvider)),
);

/// The signed-in user's notes, newest first.
final savedNotesProvider = StreamProvider.autoDispose<List<SavedNote>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(savedRepositoryProvider).watch(uid);
});
