import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/viewmodels/auth_providers.dart';
import '../../../chat/presentation/viewmodels/chat_view_model.dart';
import '../../data/media_storage_service.dart';
import '../../domain/media_uploader.dart';
import '../../domain/send_image_message_use_case.dart';
import 'attachment_providers.dart';

final mediaUploaderProvider = Provider.autoDispose<MediaUploader>(
  (ref) => MediaStorageService(ref.watch(firebaseStorageProvider)),
);

enum AttachmentPhase { idle, uploading, done, failed }

class AttachmentState {
  const AttachmentState({
    this.phase = AttachmentPhase.idle,
    this.progress = 0,
    this.failure,
  });

  final AttachmentPhase phase;
  final double progress;
  final Failure? failure;
}

class AttachmentViewModel extends Notifier<AttachmentState> {
  AttachmentViewModel(this.conversationId);
  final String conversationId;

  // Stable for the lifetime of this preview so retries are idempotent.
  final String _messageId = const Uuid().v4();
  bool _cancelled = false;

  @override
  AttachmentState build() => const AttachmentState();

  Future<void> send(File source, {String? caption, String? replyToId}) async {
    final me = ref.read(currentUidProvider);
    if (me == null || state.phase == AttachmentPhase.uploading) return;
    _cancelled = false;
    state = const AttachmentState(phase: AttachmentPhase.uploading);
    final useCase = SendImageMessageUseCase(
      ref.read(imageProcessorProvider),
      ref.read(mediaUploaderProvider),
      ref.read(chatRepositoryProvider),
    );
    try {
      await useCase(
        conversationId: conversationId,
        senderId: me,
        messageId: _messageId,
        source: source,
        caption: caption,
        replyToId: replyToId,
        onProgress: (p) {
          if (!_cancelled) {
            state = AttachmentState(
              phase: AttachmentPhase.uploading,
              progress: p,
            );
          }
        },
      );
      state = const AttachmentState(phase: AttachmentPhase.done, progress: 1);
    } catch (e) {
      final f = Failure.from(e);
      state = AttachmentState(
        phase: AttachmentPhase.failed,
        failure:
            f is UploadFailure && f.reason == UploadReason.cancelled ? null : f,
      );
    }
  }

  void cancel() {
    _cancelled = true;
    ref.read(mediaUploaderProvider).cancel();
  }
}

final attachmentViewModelProvider = NotifierProvider.autoDispose
    .family<AttachmentViewModel, AttachmentState, String>(
      AttachmentViewModel.new,
    );
