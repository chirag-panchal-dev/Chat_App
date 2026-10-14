import 'dart:io';

import 'group_models.dart';

abstract interface class GroupRepository {
  /// Creates a group (creator becomes the only admin). Returns the group id.
  Future<String> createGroup({
    required String me,
    required String name,
    required List<String> memberUids,
    File? photo,
  });

  Future<void> addMembers({
    required String groupId,
    required String actor,
    required List<String> uids,
  });

  Future<void> removeMember({
    required String groupId,
    required String actor,
    required String uid,
  });

  Future<void> setAdmin({
    required String groupId,
    required String uid,
    required bool admin,
  });

  Future<void> rename({
    required String groupId,
    required String actor,
    required String name,
  });

  /// [photo] must already be compressed (see ImageProcessor.processAvatar).
  Future<void> setPhoto({required String groupId, required File photo});

  Future<void> leave({required String groupId, required String me});

  // ---- invites (admin) ----
  /// The caller's current active invite for this group, if any.
  Stream<GroupInvite?> watchMyInvite(String groupId, String me);

  /// Revokes the caller's previous invites and creates a fresh code.
  Future<GroupInvite> createInvite({
    required String groupId,
    required String me,
    required String groupName,
  });

  Future<void> revokeInvite(String code);

  // ---- joining ----
  Future<GroupInvite?> lookupInvite(String code);
  Future<void> requestJoin({required String code, required String me});

  /// Whether [me] has a pending request for this group.
  Stream<bool> watchMyJoinRequest(String groupId, String me);
  Future<void> cancelJoinRequest({required String groupId, required String me});

  // ---- join requests (admin) ----
  Stream<List<JoinRequest>> watchJoinRequests(String groupId);
  Future<void> approveJoin({
    required String groupId,
    required String actor,
    required String uid,
  });
  Future<void> rejectJoin({required String groupId, required String uid});
}
