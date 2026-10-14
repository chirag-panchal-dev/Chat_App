import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/failure.dart';
import '../domain/safety_repository.dart';

class FirestoreSafetyRepository implements SafetyRepository {
  FirestoreSafetyRepository(this._db);
  final FirebaseFirestore _db;

  @override
  Stream<Set<String>> watchBlocked(String me) => _db
      .collection('users/$me/blocks')
      .snapshots()
      .map((q) => q.docs.map((d) => d.id).toSet())
      .handleError((Object e) => throw Failure.from(e));

  @override
  Future<void> block(String me, String other) async {
    try {
      await _db.doc('users/$me/blocks/$other').set({
        'blockedUid': other,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Failure.from(e);
    }
  }

  @override
  Future<void> unblock(String me, String other) async {
    try {
      await _db.doc('users/$me/blocks/$other').delete();
    } catch (e) {
      throw Failure.from(e);
    }
  }

  @override
  Future<void> report({
    required String reporterId,
    required String reportedUid,
    required ReportReason reason,
    String? details,
    String? conversationId,
    String? messageId,
  }) async {
    try {
      await _db.collection('reports').add({
        'reporterId': reporterId,
        'reportedUid': reportedUid,
        'reason': reason.name,
        if (details != null && details.trim().isNotEmpty)
          'details': details.trim(),
        if (conversationId != null) 'conversationId': conversationId,
        if (messageId != null) 'messageId': messageId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'open',
      });
    } catch (e) {
      throw Failure.from(e);
    }
  }
}
