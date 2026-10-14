import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/failure.dart';
import '../domain/entities/chat_message.dart';
import '../domain/repositories/chat_repository.dart';

class FirestoreChatRepository implements ChatRepository {
  FirestoreChatRepository(this._db);
  final FirebaseFirestore _db;
  final _pendingTimes = <String, DateTime>{};

  CollectionReference<Map<String, dynamic>> _messages(String cid) =>
      _db.collection('conversations').doc(cid).collection('messages');

  ChatMessage? _map(QueryDocumentSnapshot<Map<String, dynamic>> s) {
    final d = s.data();
    final sender = d['senderId'];
    final typeName = d['type'];
    final pending = s.metadata.hasPendingWrites;
    // A pending server timestamp reads as null until acknowledged; use a
    // stable local time so the optimistic bubble sorts and renders correctly.
    final DateTime? created = switch (d['createdAt']) {
      Timestamp t => t.toDate(),
      null when pending => _pendingTimes.putIfAbsent(s.id, DateTime.now),
      _ => null,
    };
    if (sender is! String || created == null) return null;
    if (!pending) _pendingTimes.remove(s.id);
    final type = switch (typeName) {
      'text' => MessageType.text,
      'image' => MessageType.image,
      _ => null,
    };
    if (type == null) return null; // unknown/invalid document: skip safely
    return ChatMessage(
      id: s.id,
      senderId: sender,
      type: type,
      createdAt: created,
      status: pending ? SendStatus.sending : SendStatus.sent,
      text: d['text'] as String?,
      mediaPath: d['mediaPath'] as String?,
      thumbnailPath: d['thumbnailPath'] as String?,
      width: (d['width'] as num?)?.toInt(),
      height: (d['height'] as num?)?.toInt(),
      replyToId: d['replyToMessageId'] as String?,
      deleted: d['deletedForEveryoneAt'] != null,
    );
  }

  @override
  Stream<List<ChatMessage>> watchLatest(String cid, int limit) => _messages(cid)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots(includeMetadataChanges: true)
      .map((q) => q.docs.map(_map).whereType<ChatMessage>().toList())
      .handleError((Object e) => throw Failure.from(e));

  @override
  Future<List<ChatMessage>> loadOlder(
    String cid,
    MessageCursor before,
    int limit,
  ) async {
    try {
      final q =
          await _messages(cid)
              .orderBy('createdAt', descending: true)
              .orderBy(FieldPath.documentId, descending: true)
              .startAfter([Timestamp.fromDate(before.createdAt), before.id])
              .limit(limit)
              .get();
      return q.docs.map(_map).whereType<ChatMessage>().toList();
    } catch (e) {
      throw Failure.from(e);
    }
  }

  Future<void> _create(
    String cid,
    String id,
    String senderId,
    Map<String, Object?> data,
  ) async {
    final ref = _messages(cid).doc(id);
    try {
      await ref.set({
        'clientMessageId': id,
        'senderId': senderId,
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'editedAt': null,
        'deletedForEveryoneAt': null,
      });
    } on FirebaseException catch (e) {
      // Messages are immutable, so re-sending an id that already committed
      // (ack lost on a flaky network) is rejected as an "update". Treat an
      // existing message of ours with the same id as success.
      if (e.code == 'permission-denied') {
        try {
          final existing = await ref.get();
          if (existing.exists && existing.data()?['senderId'] == senderId) {
            return;
          }
        } catch (_) {
          /* fall through to the original error */
        }
      }
      throw Failure.from(e);
    } catch (e) {
      throw Failure.from(e);
    }
  }

  @override
  Future<void> sendText({
    required String conversationId,
    required String messageId,
    required String senderId,
    required String text,
    String? replyToId,
  }) => _create(conversationId, messageId, senderId, {
    'type': 'text',
    'text': text,
    'replyToMessageId': replyToId,
  });

  @override
  Future<void> sendImage({
    required String conversationId,
    required String messageId,
    required String senderId,
    required ImagePayload image,
    String? replyToId,
  }) => _create(conversationId, messageId, senderId, {
    'type': 'image',
    if (image.caption != null && image.caption!.isNotEmpty)
      'text': image.caption,
    'mediaPath': image.mediaPath,
    'thumbnailPath': image.thumbnailPath,
    'mimeType': image.mimeType,
    'sizeBytes': image.sizeBytes,
    'width': image.width,
    'height': image.height,
    'replyToMessageId': replyToId,
  });

  @override
  Future<void> deleteForEveryone(String cid, String mid) async {
    try {
      // Content is wiped (orphaned media is later removed by the cleanup job).
      await _messages(cid).doc(mid).update({
        'deletedForEveryoneAt': FieldValue.serverTimestamp(),
        'text': FieldValue.delete(),
        'mediaPath': FieldValue.delete(),
        'thumbnailPath': FieldValue.delete(),
        'mimeType': FieldValue.delete(),
        'sizeBytes': FieldValue.delete(),
        'width': FieldValue.delete(),
        'height': FieldValue.delete(),
      });
    } catch (e) {
      throw Failure.from(e);
    }
  }

  @override
  Stream<Set<String>> watchHidden(String cid, String uid) => _db
      .collection('conversations/$cid/members/$uid/hidden')
      .limit(1000)
      .snapshots()
      .map((q) => q.docs.map((d) => d.id).toSet())
      .handleError((Object e) => throw Failure.from(e));

  @override
  Future<void> hideMessage(String cid, String uid, String mid) async {
    try {
      await _db.doc('conversations/$cid/members/$uid/hidden/$mid').set({
        'hiddenAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Failure.from(e);
    }
  }

  DocumentReference<Map<String, dynamic>> _receipt(String cid, String uid) =>
      _db.doc('conversations/$cid/receipts/$uid');

  @override
  Stream<Receipts> watchReceipts(String cid, String uid) => _receipt(cid, uid)
      .snapshots()
      .map((s) {
        final d = s.data();
        DateTime? t(Object? v) => v is Timestamp ? v.toDate() : null;
        return Receipts(
          lastDeliveredAt: t(d?['lastDeliveredAt']),
          lastReadAt: t(d?['lastReadAt']),
        );
      })
      .handleError((Object e) => throw Failure.from(e));

  @override
  Future<void> markDelivered(String cid, String uid) async {
    try {
      await _receipt(cid, uid).set({
        'lastDeliveredAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Failure.from(e);
    }
  }

  @override
  Future<void> markReadReceipt(String cid, String uid) async {
    try {
      await _receipt(cid, uid).set({
        'lastDeliveredAt': FieldValue.serverTimestamp(),
        'lastReadAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Failure.from(e);
    }
  }

  DocumentReference<Map<String, dynamic>> _typing(String cid, String uid) =>
      _db.doc('conversations/$cid/typing/$uid');

  @override
  Stream<DateTime?> watchTyping(String cid, String uid) {
    var first = true;
    return _typing(cid, uid)
        .snapshots()
        .map((s) {
          final v = s.data()?['typingAt'];
          final initial = first;
          first = false;
          if (!s.exists || v is! Timestamp) return null;
          // Opening a chat must not show a stale "typing" left behind earlier.
          if (initial &&
              DateTime.now().difference(v.toDate()).abs() >
                  const Duration(seconds: 8)) {
            return null;
          }
          // Receipt time on this device, so clock skew can't break the 6s window.
          return DateTime.now();
        })
        .handleError((Object e) => throw Failure.from(e));
  }

  @override
  Future<void> setTyping(String cid, String uid) async {
    try {
      await _typing(cid, uid).set({'typingAt': FieldValue.serverTimestamp()});
    } catch (e) {
      throw Failure.from(e);
    }
  }

  @override
  Future<void> clearTyping(String cid, String uid) async {
    try {
      await _typing(cid, uid).delete();
    } catch (e) {
      throw Failure.from(e);
    }
  }

  @override
  Stream<Map<String, String>> watchReactions(String cid, String mid) => _db
      .collection('conversations/$cid/messages/$mid/reactions')
      .snapshots()
      .map(
        (q) => {
          for (final d in q.docs)
            if (d.data()['emoji'] is String) d.id: d.data()['emoji'] as String,
        },
      )
      .handleError((Object e) => throw Failure.from(e));

  @override
  Future<void> setReaction(
    String cid,
    String mid,
    String uid,
    String? emoji,
  ) async {
    final ref = _db.doc('conversations/$cid/messages/$mid/reactions/$uid');
    try {
      if (emoji == null) {
        await ref.delete();
      } else {
        await ref.set({
          'emoji': emoji,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw Failure.from(e);
    }
  }
}
