enum ReportReason { spam, harassment, inappropriate, impersonation, other }

abstract interface class SafetyRepository {
  /// UIDs the user has blocked.
  Stream<Set<String>> watchBlocked(String me);
  Future<void> block(String me, String other);
  Future<void> unblock(String me, String other);

  /// Reports are write-only for clients; only moderators can read them.
  Future<void> report({
    required String reporterId,
    required String reportedUid,
    required ReportReason reason,
    String? details,
    String? conversationId,
    String? messageId,
  });
}
