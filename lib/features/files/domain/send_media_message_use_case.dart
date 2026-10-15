import 'dart:io';

import '../../../core/errors/failure.dart';
import '../../../core/utils/retry.dart';
import '../../attachments/domain/media_uploader.dart';
import '../../chat/domain/repositories/chat_repository.dart';
import 'file_rules.dart';
import 'picked_media.dart';

/// Upload the file, then write the message document. The Storage path and
/// message id derive from [messageId], so a retry reuses the same object and
/// document: no duplicates. "Sent" only happens after both succeed.
class SendMediaMessageUseCase {
  const SendMediaMessageUseCase(this._uploader, this._chat);

  final MediaUploader _uploader;
  final ChatRepository _chat;

  Future<void> sendDocument({
    required String conversationId,
    required String senderId,
    required String messageId,
    required PickedDocument doc,
    String? replyToId,
    void Function(double progress)? onProgress,
  }) async {
    final base = 'chatMedia/$conversationId/$senderId/$messageId';
    final path = '$base.${fileExtension(doc.fileName)}';
    final thumb = await _uploadPreview(doc.preview, '${base}_thumb.jpg');
    await retryTransient(
      () => _uploader.upload(
        path,
        doc.file,
        contentType: doc.mimeType,
        onProgress: onProgress,
      ),
    );
    await retryTransient(
      () => _chat.sendFile(
        conversationId: conversationId,
        messageId: messageId,
        senderId: senderId,
        mediaPath: path,
        mimeType: doc.mimeType,
        sizeBytes: doc.sizeBytes,
        fileName: doc.fileName,
        thumbnailPath: thumb,
        pageCount: doc.pageCount,
        replyToId: replyToId,
      ),
    );
  }

  Future<void> sendVideo({
    required String conversationId,
    required String senderId,
    required String messageId,
    required PickedVideo video,
    String? replyToId,
    void Function(double progress)? onProgress,
  }) async {
    final ext = video.mimeType == 'video/quicktime' ? 'mov' : 'mp4';
    final base = 'chatMedia/$conversationId/$senderId/$messageId';
    final path = '$base.$ext';
    final thumb = await _uploadPreview(video.thumbnail, '${base}_thumb.jpg');
    await retryTransient(
      () => _uploader.upload(
        path,
        video.file,
        contentType: video.mimeType,
        onProgress: onProgress,
      ),
    );
    await retryTransient(
      () => _chat.sendVideo(
        conversationId: conversationId,
        messageId: messageId,
        senderId: senderId,
        mediaPath: path,
        mimeType: video.mimeType,
        sizeBytes: video.sizeBytes,
        durationMs: video.duration.inMilliseconds,
        width: video.width,
        height: video.height,
        thumbnailPath: thumb,
        replyToId: replyToId,
      ),
    );
  }

  /// Uploads a small preview image; a failure only means "no preview", the
  /// message itself is still sent.
  Future<String?> _uploadPreview(File? image, String path) async {
    if (image == null) return null;
    try {
      await _uploader.upload(path, image, contentType: 'image/jpeg');
      return path;
    } catch (e) {
      final f = Failure.from(e);
      if (f is UploadFailure && f.reason == UploadReason.cancelled) rethrow;
      return null;
    }
  }
}
