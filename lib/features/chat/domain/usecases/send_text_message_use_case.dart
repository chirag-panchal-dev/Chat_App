import '../../../../core/utils/validators.dart';
import '../repositories/chat_repository.dart';

/// Validates and sends a text message. The caller supplies the stable
/// client-generated [messageId] so retries are idempotent.
class SendTextMessageUseCase {
  const SendTextMessageUseCase(this._repo);
  final ChatRepository _repo;

  /// Returns the trimmed text that was sent. Throws [ValidationFailure] for
  /// blank/oversized input and a typed `Failure` for transport errors.
  Future<String> call({
    required String conversationId,
    required String messageId,
    required String senderId,
    required String text,
    String? replyToId,
  }) async {
    final clean = FieldValidators.messageText(text);
    await _repo.sendText(
      conversationId: conversationId,
      messageId: messageId,
      senderId: senderId,
      text: clean,
      replyToId: replyToId,
    );
    return clean;
  }
}
