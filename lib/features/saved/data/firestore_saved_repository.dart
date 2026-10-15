import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/failure.dart';
import '../domain/saved_note.dart';
import '../domain/saved_repository.dart';

class FirestoreSavedRepository implements SavedRepository {
  FirestoreSavedRepository(this._db);
  final FirebaseFirestore _db;

  static const _limit = 500;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users/$uid/saved');

  @override
  Stream<List<SavedNote>> watch(String uid) => _col(uid)
      .orderBy('createdAt', descending: true)
      .limit(_limit)
      .snapshots(includeMetadataChanges: true)
      .map(
        (q) => [
          for (final d in q.docs)
            if (d.data()['text'] is String)
              SavedNote(
                id: d.id,
                text: d.data()['text'] as String,
                // A pending server timestamp reads as null until acknowledged.
                createdAt:
                    (d.data()['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
                sourceName: d.data()['sourceName'] as String?,
                pending: d.metadata.hasPendingWrites,
              ),
        ],
      )
      .handleError((Object e) => throw Failure.from(e));

  @override
  Future<void> add(String uid, String text, {String? sourceName}) async {
    try {
      await _col(uid).add({
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        if (sourceName != null && sourceName.isNotEmpty)
          'sourceName':
              sourceName.length > 100
                  ? sourceName.substring(0, 100)
                  : sourceName,
      });
    } catch (e) {
      throw Failure.from(e);
    }
  }

  @override
  Future<void> delete(String uid, String noteId) async {
    try {
      await _col(uid).doc(noteId).delete();
    } catch (e) {
      throw Failure.from(e);
    }
  }
}
