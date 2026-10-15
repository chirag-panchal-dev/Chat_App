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

  /// Voice note whose audio is already uploaded to [mediaPath].
  Future<void> sendVoice({
    required String conversationId,
    required String messageId,
    required String senderId,
    required String mediaPath,
    required String mimeType,
    required int sizeBytes,
    required int durationMs,
    required List<int> waveform,
    String? replyToId,
  });

  /// Document already uploaded to [mediaPath].
  Future<void> sendFile({
    required String conversationId,
    required String messageId,
    required String senderId,
    required String mediaPath,
    required String mimeType,
    required int sizeBytes,
    required String fileName,
    String? thumbnailPath,
    int? pageCount,
    String? replyToId,
  });

  /// Video already uploaded to [mediaPath].
  Future<void> sendVideo({
    required String conversationId,
    required String messageId,
    required String senderId,
    required String mediaPath,
    required String mimeType,
    required int sizeBytes,
    required int durationMs,
    int? width,
    int? height,
    String? thumbnailPath,
    String? replyToId,
  });

  /// Message ids the user deleted "for me".
  Stream<Set<String>> watchHidden(String conversationId, String uid);
  Future<void> hideMessage(String conversationId, String uid, String messageId);

  /// Sender-only: replaces the text of a text message (rules: within 15 min).
  Future<void> editMessage(
    String conversationId,
    String messageId,
    String text,
  );

  /// Sender-only: wipes the content and shows a tombstone to everyone.
  Future<void> deleteForEveryone(String conversationId, String messageId);

  /// The given user's delivery/read receipts for this conversation.
  Stream<Receipts> watchReceipts(String conversationId, String uid);

  /// Everyone's receipts in the conversation, keyed by uid (group chats).
  Stream<Map<String, Receipts>> watchAllReceipts(String conversationId);

  /// Everyone's typing signals keyed by uid -> local receipt time (groups).
  Stream<Map<String, DateTime>> watchTypingAll(String conversationId);

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
