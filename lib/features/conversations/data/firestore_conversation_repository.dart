import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/failure.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/validators.dart';
import '../domain/entities/conversation.dart';
import '../domain/repositories/conversation_repository.dart';

class FirestoreConversationRepository implements ConversationRepository {
  FirestoreConversationRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _conv(String id) =>
      _db.collection('conversations').doc(id);
  DocumentReference<Map<String, dynamic>> _member(String id, String uid) =>
      _conv(id).collection('members').doc(uid);

  static DateTime? _dt(Object? v) => v is Timestamp ? v.toDate() : null;

  Conversation? _map(DocumentSnapshot<Map<String, dynamic>> s) {
    final d = s.data();
    if (d == null) return null;
    final members = (d['memberIds'] as List?)?.whereType<String>().toList();
    final isGroup = d['type'] == 'group';
    if (members == null ||
        (isGroup
            ? members.isEmpty || members.length > maxGroupMembers
            : members.length != 2)) {
      return null; // invalid doc
    }
    return Conversation(
      id: s.id,
      memberIds: members,
      type: isGroup ? ConversationType.group : ConversationType.direct,
      name: d['name'] as String?,
      photoPath: d['photoPath'] as String?,
      adminIds:
          (d['adminIds'] as List?)?.whereType<String>().toList() ?? const [],
      createdBy: d['createdBy'] as String?,
      lastMessagePreview: d['lastMessagePreview'] as String?,
      lastMessageAt: _dt(d['lastMessageAt']),
      lastSenderId: d['lastSenderId'] as String?,
      disappearAfterSec: (d['disappearAfterSec'] as num?)?.toInt() ?? 0,
      deletedAccounts:
          (d['deletedAccounts'] as List?)?.whereType<String>().toList() ??
          const [],
    );
  }

  @override
  Stream<List<Conversation>> watchConversations(String uid) => _db
      .collection('conversations')
      .where('memberIds', arrayContains: uid)
      .orderBy('lastMessageAt', descending: true)
      .limit(AppConfig.conversationLimit)
      .snapshots()
      .map((q) => q.docs.map(_map).whereType<Conversation>().toList())
      .handleError((Object e) => throw Failure.from(e));

  @override
  Stream<Conversation?> watchConversation(String id) =>
      _conv(id).snapshots().map(_map).handleError((Object e) {
        throw Failure.from(e);
      });

  @override
  Stream<MemberPrefs> watchMemberPrefs(String id, String uid) =>
      _member(id, uid)
          .snapshots()
          .map((s) {
            final d = s.data();
            if (d == null) return const MemberPrefs();
            return MemberPrefs(
              lastReadAt: _dt(d['lastReadAt']),
              mutedUntil: _dt(d['mutedUntil']),
              archived: d['archived'] as bool? ?? false,
              pinned: d['pinned'] as bool? ?? false,
              clearedAt: _dt(d['clearedAt']),
              chatTheme: d['chatTheme'] as String?,
            );
          })
          .handleError((Object e) => throw Failure.from(e));

  Map<String, Object?> _newMember() => {
    'joinedAt': FieldValue.serverTimestamp(),
    'lastReadAt': null,
    'mutedUntil': null,
    'archived': false,
    'pinned': false,
  };

  @override
  Future<String> startDirect(String me, String other) async {
    if (me == other) {
      throw const ValidationFailure(ValidationReason.selfConversation);
    }
    final id = ConversationIds.direct(me, other);
    try {
      // A read of a not-yet-existing conversation is denied by the rules, so
      // permission-denied here means "does not exist (yet)".
      var exists = false;
      try {
        exists = (await _conv(id).get()).exists;
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
      }
      if (!exists) {
        final members = ConversationIds.sortedMembers(me, other);
        final batch = _db.batch();
        batch.set(_conv(id), {
          'type': 'direct',
          'memberIds': members,
          'createdBy': me,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessageId': null,
          'lastMessageAt': null,
          'lastMessagePreview': null,
          'lastSenderId': null,
        });
        batch.set(_member(id, me), _newMember());
        try {
          await batch.commit();
        } on FirebaseException catch (e) {
          // Lost a race with the other participant creating it: that is fine.
          if (e.code != 'permission-denied') rethrow;
          final again = await _conv(
            id,
          ).get().then((s) => s.exists, onError: (_) => false);
          if (!again) rethrow;
        }
      }
      await ensureMember(id, me);
      return id;
    } on Failure {
      rethrow;
    } catch (e) {
      throw Failure.from(e);
    }
  }

  @override
  Future<void> ensureMember(String id, String uid) async {
    try {
      final ref = _member(id, uid);
      final snap = await ref.get();
      if (!snap.exists) await ref.set(_newMember());
    } catch (e) {
      throw Failure.from(e);
    }
  }

  Future<void> _update(String id, String uid, Map<String, Object?> data) async {
    try {
      await ensureMember(id, uid);
      await _member(id, uid).update(data);
    } catch (e) {
      throw Failure.from(e);
    }
  }

  @override
  Future<void> setPinned(String id, String uid, bool v) =>
      _update(id, uid, {'pinned': v});

  @override
  Future<void> setArchived(String id, String uid, bool v) =>
      _update(id, uid, {'archived': v});

  @override
  Future<void> setMutedUntil(String id, String uid, DateTime? until) => _update(
    id,
    uid,
    {'mutedUntil': until == null ? null : Timestamp.fromDate(until)},
  );

  @override
  Future<void> setDisappearAfter(String id, String uid, int seconds) async {
    try {
      final batch = _db.batch();
      batch.update(_conv(id), {'disappearAfterSec': seconds});
      final msgId = const Uuid().v4();
      batch.set(_conv(id).collection('messages').doc(msgId), {
        'clientMessageId': msgId,
        'senderId': uid,
        'type': 'system',
        'event': 'timer',
        'timerSec': seconds,
        'createdAt': FieldValue.serverTimestamp(),
        'editedAt': null,
        'deletedForEveryoneAt': null,
      });
      await batch.commit();
    } catch (e) {
      throw Failure.from(e);
    }
  }

  @override
  Future<void> setChatTheme(String id, String uid, String? themeId) =>
      _update(id, uid, {'chatTheme': themeId ?? FieldValue.delete()});

  @override
  Future<void> clearChat(String id, String uid) =>
      _update(id, uid, {'clearedAt': FieldValue.serverTimestamp()});

  @override
  Future<void> markRead(String id, String uid) =>
      _update(id, uid, {'lastReadAt': FieldValue.serverTimestamp()});
}
