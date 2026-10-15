import '../entities/conversation.dart';

abstract interface class ConversationRepository {
  /// Bounded, newest-activity-first list of the user's conversations.
  Stream<List<Conversation>> watchConversations(String uid);

  Stream<Conversation?> watchConversation(String conversationId);

  Stream<MemberPrefs> watchMemberPrefs(String conversationId, String uid);

  /// Returns the stable direct conversation id, creating it if necessary.
  Future<String> startDirect(String me, String other);

  /// Creates the user's own member doc if missing (e.g. chat started by the
  /// other participant).
  Future<void> ensureMember(String conversationId, String uid);

  Future<void> setPinned(String conversationId, String uid, bool value);
  Future<void> setArchived(String conversationId, String uid, bool value);
  Future<void> setMutedUntil(
    String conversationId,
    String uid,
    DateTime? until,
  );

  /// Turns disappearing messages on/off for everyone in the chat and posts a
  /// notice. Groups: admins only (rules enforce it).
  Future<void> setDisappearAfter(
    String conversationId,
    String uid,
    int seconds,
  );

  /// This user's own chat look (`null` = back to the default).
  Future<void> setChatTheme(String conversationId, String uid, String? themeId);

  /// Clears the chat for this user only (hides everything up to now).
  Future<void> clearChat(String conversationId, String uid);

  /// Records that the user has read up to now.
  Future<void> markRead(String conversationId, String uid);
}
