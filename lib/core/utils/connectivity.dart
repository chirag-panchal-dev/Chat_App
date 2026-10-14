import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True while the device has some network transport. This only reflects the
/// radio state (not actual reachability); Firestore queues writes either way.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  bool online(List<ConnectivityResult> r) =>
      r.any((x) => x != ConnectivityResult.none);
  yield online(await c.checkConnectivity());
  yield* c.onConnectivityChanged.map(online);
});
