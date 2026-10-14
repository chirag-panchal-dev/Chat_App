class GroupInvite {
  const GroupInvite({
    required this.code,
    required this.groupId,
    required this.groupName,
    this.active = true,
  });

  final String code;
  final String groupId;
  final String groupName;
  final bool active;
}

class JoinRequest {
  const JoinRequest({required this.uid, required this.code, this.createdAt});
  final String uid;
  final String code;
  final DateTime? createdAt;
}

/// Result of leaving: the member/admin lists to write back.
class LeavePlan {
  const LeavePlan({required this.memberIds, required this.adminIds});
  final List<String> memberIds;
  final List<String> adminIds;
}
