import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failure.dart';
import '../../conversations/domain/entities/conversation.dart';
import '../domain/group_models.dart';
import '../domain/group_repository.dart';
import '../domain/group_rules.dart';

class FirestoreGroupRepository implements GroupRepository {
  FirestoreGroupRepository(this._db, this._storage);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  static const _uuid = Uuid();

  DocumentReference<Map<String, dynamic>> _group(String id) =>
      _db.collection('conversations').doc(id);
  CollectionReference<Map<String, dynamic>> get _invites =>
      _db.collection('groupInvites');

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on Failure {
      rethrow;
    } catch (e) {
      throw Failure.from(e);
    }
  }

  /// A system message (member added/removed/left, rename) written in the same
  /// batch as the change it describes.
  void _system(
    WriteBatch b,
    String gid,
    String actor,
    String event, {
    String? target,
  }) {
    final id = _uuid.v4();
    b.set(_group(gid).collection('messages').doc(id), {
      'clientMessageId': id,
      'senderId': actor,
      'type': 'system',
      'event': event,
      if (target != null) 'targetUid': target,
      'createdAt': FieldValue.serverTimestamp(),
      'editedAt': null,
      'deletedForEveryoneAt': null,
    });
  }

  Future<Conversation> _read(String gid) async {
    final s = await _group(gid).get();
    final d = s.data();
    final members = (d?['memberIds'] as List?)?.whereType<String>().toList();
    if (d == null || members == null) {
      throw const PermissionFailure();
    }
    return Conversation(
      id: gid,
      memberIds: members,
      type: ConversationType.group,
      name: d['name'] as String?,
      adminIds:
          (d['adminIds'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }

  @override
  Future<String> createGroup({
    required String me,
    required String name,
    required List<String> memberUids,
    File? photo,
  }) => _guard(() async {
    if (!GroupRules.isValidName(name)) {
      throw const ValidationFailure(ValidationReason.displayNameInvalid);
    }
    final others = memberUids.where((u) => u != me).toSet().toList();
    final members = [me, ...others];
    if (members.length < 2 || members.length > maxGroupMembers) {
      throw const ValidationFailure(ValidationReason.other);
    }
    final gid = 'g_${_uuid.v4().replaceAll('-', '')}';
    final batch = _db.batch();
    batch.set(_group(gid), {
      'type': 'group',
      'memberIds': members,
      'adminIds': [me],
      'name': name.trim(),
      'photoPath': null,
      'createdBy': me,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessageId': null,
      'lastMessageAt': null,
      'lastMessagePreview': null,
      'lastSenderId': null,
    });
    batch.set(_group(gid).collection('members').doc(me), {
      'joinedAt': FieldValue.serverTimestamp(),
      'lastReadAt': null,
      'mutedUntil': null,
      'archived': false,
      'pinned': false,
    });
    await batch.commit();
    if (photo != null) {
      // The photo rule needs the group to exist (admin check), so it is
      // uploaded after creation.
      try {
        await setPhoto(groupId: gid, photo: photo);
      } catch (_) {
        // The group is created; a failed photo can be retried from group info.
      }
    }
    return gid;
  });

  @override
  Future<void> addMembers({
    required String groupId,
    required String actor,
    required List<String> uids,
  }) => _guard(() async {
    final g = await _read(groupId);
    final fresh = uids.where((u) => !g.memberIds.contains(u)).toSet().toList();
    if (fresh.isEmpty) return;
    if (!GroupRules.canAdd(g.memberIds.length, fresh.length)) {
      throw const ValidationFailure(ValidationReason.other);
    }
    final batch = _db.batch();
    batch.update(_group(groupId), {
      'memberIds': FieldValue.arrayUnion(fresh),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final u in fresh) {
      _system(batch, groupId, actor, 'added', target: u);
    }
    await batch.commit();
  });

  @override
  Future<void> removeMember({
    required String groupId,
    required String actor,
    required String uid,
  }) => _guard(() async {
    final g = await _read(groupId);
    if (GroupRules.isLastAdmin(g.adminIds, uid)) {
      throw const ValidationFailure(ValidationReason.other);
    }
    final batch = _db.batch();
    batch.update(_group(groupId), {
      'memberIds': FieldValue.arrayRemove([uid]),
      'adminIds': FieldValue.arrayRemove([uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _system(batch, groupId, actor, 'removed', target: uid);
    await batch.commit();
  });

  @override
  Future<void> setAdmin({
    required String groupId,
    required String uid,
    required bool admin,
  }) => _guard(() async {
    if (!admin) {
      final g = await _read(groupId);
      if (GroupRules.isLastAdmin(g.adminIds, uid)) {
        throw const ValidationFailure(ValidationReason.other);
      }
    }
    await _group(groupId).update({
      'adminIds':
          admin ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });

  @override
  Future<void> rename({
    required String groupId,
    required String actor,
    required String name,
  }) => _guard(() async {
    if (!GroupRules.isValidName(name)) {
      throw const ValidationFailure(ValidationReason.displayNameInvalid);
    }
    final batch = _db.batch();
    batch.update(_group(groupId), {
      'name': name.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _system(batch, groupId, actor, 'renamed');
    await batch.commit();
  });

  @override
  Future<void> setPhoto({
    required String groupId,
    required File photo,
  }) => _guard(() async {
    final path =
        'groupAvatars/$groupId/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _storage
        .ref(path)
        .putFile(photo, SettableMetadata(contentType: 'image/jpeg'));
    await _group(
      groupId,
    ).update({'photoPath': path, 'updatedAt': FieldValue.serverTimestamp()});
  });

  @override
  Future<void> leave({required String groupId, required String me}) =>
      _guard(() async {
        final g = await _read(groupId);
        final plan = GroupRules.planLeave(
          members: g.memberIds,
          admins: g.adminIds,
          me: me,
        );
        final batch = _db.batch();
        // Written first: the rules evaluate it against the pre-batch state,
        // where the user is still a member.
        _system(batch, groupId, me, 'left', target: me);
        batch.update(_group(groupId), {
          'memberIds': plan.memberIds,
          'adminIds': plan.adminIds,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await batch.commit();
      });

  // ------------------------------------------------------------- invites

  GroupInvite? _inviteFrom(DocumentSnapshot<Map<String, dynamic>> s) {
    final d = s.data();
    if (d == null) return null;
    final gid = d['gid'];
    final name = d['groupName'];
    if (gid is! String || name is! String) return null;
    return GroupInvite(
      code: s.id,
      groupId: gid,
      groupName: name,
      active: d['active'] as bool? ?? false,
    );
  }

  @override
  Stream<GroupInvite?> watchMyInvite(String groupId, String me) => _invites
      .where('createdBy', isEqualTo: me)
      .where('gid', isEqualTo: groupId)
      .where('active', isEqualTo: true)
      .limit(1)
      .snapshots()
      .map((q) => q.docs.isEmpty ? null : _inviteFrom(q.docs.first))
      .handleError((Object e) => throw Failure.from(e));

  @override
  Future<GroupInvite> createInvite({
    required String groupId,
    required String me,
    required String groupName,
  }) => _guard(() async {
    final old =
        await _invites
            .where('createdBy', isEqualTo: me)
            .where('gid', isEqualTo: groupId)
            .where('active', isEqualTo: true)
            .get();
    final code = GroupRules.generateInviteCode();
    final batch = _db.batch();
    for (final d in old.docs) {
      batch.update(d.reference, {'active': false});
    }
    batch.set(_invites.doc(code), {
      'gid': groupId,
      'groupName': groupName,
      'createdBy': me,
      'createdAt': FieldValue.serverTimestamp(),
      'active': true,
    });
    await batch.commit();
    return GroupInvite(code: code, groupId: groupId, groupName: groupName);
  });

  @override
  Future<void> revokeInvite(String code) =>
      _guard(() => _invites.doc(code).update({'active': false}));

  @override
  Future<GroupInvite?> lookupInvite(String code) => _guard(() async {
    final inv = _inviteFrom(await _invites.doc(code).get());
    return (inv != null && inv.active) ? inv : null;
  });

  // ------------------------------------------------------------ joining

  @override
  Future<void> requestJoin({required String code, required String me}) =>
      _guard(() async {
        final inv = await lookupInvite(code);
        if (inv == null) {
          throw const ValidationFailure(ValidationReason.other);
        }
        await _group(inv.groupId).collection('joinRequests').doc(me).set({
          'uid': me,
          'code': code,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

  @override
  Stream<bool> watchMyJoinRequest(String groupId, String me) => _group(groupId)
      .collection('joinRequests')
      .doc(me)
      .snapshots()
      .map((s) => s.exists)
      .handleError((Object e) => throw Failure.from(e));

  @override
  Future<void> cancelJoinRequest({
    required String groupId,
    required String me,
  }) =>
      _guard(() => _group(groupId).collection('joinRequests').doc(me).delete());

  @override
  Stream<List<JoinRequest>> watchJoinRequests(String groupId) => _group(groupId)
      .collection('joinRequests')
      .snapshots()
      .map(
        (q) =>
            q.docs.map((d) {
                final data = d.data();
                final ts = data['createdAt'];
                return JoinRequest(
                  uid: d.id,
                  code: data['code'] as String? ?? '',
                  createdAt: ts is Timestamp ? ts.toDate() : null,
                );
              }).toList()
              ..sort(
                (a, b) => (a.createdAt ?? DateTime.now()).compareTo(
                  b.createdAt ?? DateTime.now(),
                ),
              ),
      )
      .handleError((Object e) => throw Failure.from(e));

  @override
  Future<void> approveJoin({
    required String groupId,
    required String actor,
    required String uid,
  }) => _guard(() async {
    final g = await _read(groupId);
    if (!g.memberIds.contains(uid)) {
      if (!GroupRules.canAdd(g.memberIds.length, 1)) {
        throw const ValidationFailure(ValidationReason.other);
      }
      final batch = _db.batch();
      batch.update(_group(groupId), {
        'memberIds': FieldValue.arrayUnion([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.delete(_group(groupId).collection('joinRequests').doc(uid));
      _system(batch, groupId, actor, 'added', target: uid);
      await batch.commit();
    } else {
      await _group(groupId).collection('joinRequests').doc(uid).delete();
    }
  });

  @override
  Future<void> rejectJoin({required String groupId, required String uid}) =>
      _guard(
        () => _group(groupId).collection('joinRequests').doc(uid).delete(),
      );
}
