import '../entities/chat_message.dart';

class ImagePayload {
  const ImagePayload({
    required this.mediaPath,
    required this.thumbnailPath,
    required this.mimeType,
    required this.sizeBytes,
    required this.width,
    required this.height,
    this.caption,
  });

  final String mediaPath;
  final String thumbnailPath;
  final String mimeType;
  final int sizeBytes;
  final int width;
  final int height;
  final String? caption;
}

abstract interface class ChatRepository {
  /// Newest [limit] messages, including locally pending writes.
  Stream<List<ChatMessage>> watchLatest(String conversationId, int limit);

  /// Next page of messages older than [before].
  Future<List<ChatMessage>> loadOlder(
    String conversationId,
    MessageCursor before,
    int limit,
  );

  /// Idempotent: the Firestore document id is [messageId], so a retry can
  /// never create a duplicate bubble.
  Future<void> sendText({
    required String conversationId,
    required String messageId,
    required String senderId,
    required String text,
    String? replyToId,
  });

  Future<void> sendImage({
    required String conversationId,
    required String messageId,
    required String senderId,
    required ImagePayload image,
    String? replyToId,
  });

  /// Message ids the user deleted "for me".
  Stream<Set<String>> watchHidden(String conversationId, String uid);
  Future<void> hideMessage(String conversationId, String uid, String messageId);

  /// Sender-only: wipes the content and shows a tombstone to everyone.
  Future<void> deleteForEveryone(String conversationId, String messageId);

  /// The given user's delivery/read receipts for this conversation.
  Stream<Receipts> watchReceipts(String conversationId, String uid);

  /// Records that [uid]'s app has received messages up to now.
  Future<void> markDelivered(String conversationId, String uid);

  /// Records that [uid] has read the conversation up to now. Only call when
  /// the user has read receipts enabled.
  Future<void> markReadReceipt(String conversationId, String uid);

  /// Emits a local timestamp each time [uid] signals that they are typing,
  /// and null when they stop. Stale signals are filtered out.
  Stream<DateTime?> watchTyping(String conversationId, String uid);

  /// Signals that [uid] is typing (callers throttle this).
  Future<void> setTyping(String conversationId, String uid);
  Future<void> clearTyping(String conversationId, String uid);

  /// uid -> emoji for one message.
  Stream<Map<String, String>> watchReactions(
    String conversationId,
    String messageId,
  );
  Future<void> setReaction(
    String conversationId,
    String messageId,
    String uid,
    String? emoji,
  );
}
