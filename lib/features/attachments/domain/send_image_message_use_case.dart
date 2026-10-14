import 'dart:io';

import '../../../core/utils/retry.dart';
import '../../chat/domain/repositories/chat_repository.dart';
import '../data/image_processor.dart';
import 'media_uploader.dart';

/// Validate → compress → upload thumbnail + image → write the message doc.
///
/// The message is only written (and therefore only appears as "sent") after
/// both uploads succeed. All paths derive from [messageId], so a retry reuses
/// the same Storage objects and the same message document: no duplicates.
class SendImageMessageUseCase {
  const SendImageMessageUseCase(this._processor, this._uploader, this._chat);

  final ImageProcessor _processor;
  final MediaUploader _uploader;
  final ChatRepository _chat;

  Future<void> call({
    required String conversationId,
    required String senderId,
    required String messageId,
    required File source,
    String? caption,
    String? replyToId,
    void Function(double progress)? onProgress,
  }) async {
    final processed = await _processor.processForChat(source, messageId);
    final base = 'chatMedia/$conversationId/$senderId/$messageId';
    final mediaPath = '$base.jpg';
    final thumbPath = '${base}_thumb.jpg';

    // Thumbnail is tiny; weight progress mostly on the main image.
    await retryTransient(
      () => _uploader.upload(
        thumbPath,
        processed.thumbnail,
        contentType: processed.mimeType,
        onProgress: (p) => onProgress?.call(p * 0.1),
      ),
    );
    await retryTransient(
      () => _uploader.upload(
        mediaPath,
        processed.file,
        contentType: processed.mimeType,
        onProgress: (p) => onProgress?.call(0.1 + p * 0.9),
      ),
    );

    await retryTransient(
      () => _chat.sendImage(
        conversationId: conversationId,
        messageId: messageId,
        senderId: senderId,
        replyToId: replyToId,
        image: ImagePayload(
          mediaPath: mediaPath,
          thumbnailPath: thumbPath,
          mimeType: processed.mimeType,
          sizeBytes: processed.sizeBytes,
          width: processed.width,
          height: processed.height,
          caption: caption?.trim(),
        ),
      ),
    );
  }
}
