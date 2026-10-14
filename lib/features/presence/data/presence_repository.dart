import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/failure.dart';

/// Online / last-seen presence in `presence/{uid}` (`lastActiveAt` only).
///
/// Firestore has no native presence, so this is deliberately approximate:
/// the app writes a heartbeat about once a minute while foregrounded and once
/// more when it goes to the background. "Online" means active within the last
/// ~2 minutes and can lag.
class PresenceRepository {
  PresenceRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.doc('presence/$uid');

  /// Last-active time, or null when hidden/unknown.
  Stream<DateTime?> watch(String uid) => _doc(uid)
      .snapshots()
      .map((s) {
        final v = s.data()?['lastActiveAt'];
        return v is Timestamp ? v.toDate() : null;
      })
      .handleError((Object e) => throw Failure.from(e));

  Future<void> touch(String uid) async {
    try {
      await _doc(uid).set({'lastActiveAt': FieldValue.serverTimestamp()});
    } catch (e) {
      throw Failure.from(e);
    }
  }

  /// Removes the doc so nobody can see when the user was last online.
  Future<void> hide(String uid) async {
    try {
      await _doc(uid).delete();
    } catch (e) {
      throw Failure.from(e);
    }
  }
}
