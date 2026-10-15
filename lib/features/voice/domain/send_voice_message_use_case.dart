import '../../../core/utils/retry.dart';
import '../../attachments/domain/media_uploader.dart';
import '../../chat/domain/repositories/chat_repository.dart';
import 'voice_models.dart';

/// Upload the audio, then write the message document. The Storage path and
/// message id derive from [messageId], so a retry reuses the same object and
/// document: no duplicates. "Sent" only happens after both succeed.
class SendVoiceMessageUseCase {
  const SendVoiceMessageUseCase(this._uploader, this._chat);

  final MediaUploader _uploader;
  final ChatRepository _chat;

  Future<void> call({
    required String conversationId,
    required String senderId,
    required String messageId,
    required VoiceRecording recording,
    String? replyToId,
    void Function(double progress)? onProgress,
  }) async {
    final path = 'chatMedia/$conversationId/$senderId/$messageId.m4a';
    final size = await recording.file.length();
    await retryTransient(
      () => _uploader.upload(
        path,
        recording.file,
        contentType: VoiceLimits.mimeType,
        onProgress: onProgress,
      ),
    );
    await retryTransient(
      () => _chat.sendVoice(
        conversationId: conversationId,
        messageId: messageId,
        senderId: senderId,
        mediaPath: path,
        mimeType: VoiceLimits.mimeType,
        sizeBytes: size,
        durationMs: recording.durationMs,
        waveform: recording.waveform,
        replyToId: replyToId,
      ),
    );
  }
}
