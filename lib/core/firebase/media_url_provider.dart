import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_providers.dart';

/// Resolves a Storage path to a short-lived authorized download URL.
/// Messages and profiles store only the path (never a permanent public URL).
/// Kept alive so scrolling a list does not re-resolve the same path.
final mediaUrlProvider = FutureProvider.family<String, String>((ref, path) {
  ref.keepAlive();
  return ref.watch(firebaseStorageProvider).ref(path).getDownloadURL();
});
