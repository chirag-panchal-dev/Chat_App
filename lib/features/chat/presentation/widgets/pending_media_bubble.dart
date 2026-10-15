import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/theme/hushlo_colors.dart';
import '../../../../core/errors/failure.dart';
import '../../../files/presentation/widgets/file_bubble_content.dart';
import '../../../files/presentation/widgets/pending_ring.dart';
import '../../../files/presentation/widgets/video_bubble_content.dart';
import '../../domain/entities/chat_message.dart';
import '../viewmodels/chat_view_model.dart';
import 'message_ticks.dart';

/// A document or video that is still uploading, or failed, drawn as the same
/// card it becomes once sent (WhatsApp style): local preview, a progress ring
/// with cancel over it, and on failure a retry control plus "Not sent".
class PendingMediaBubble extends StatelessWidget {
  const PendingMediaBubble({
    super.key,
    required this.upload,
    required this.onRetry,
    required this.onDiscard,
  });

  final MediaUpload upload;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final failed = upload.failed;
    final rejected = upload.failure is PermissionFailure;
    Widget ring(double size) => PendingRing(
      size: size,
      progress: upload.progress,
      failed: failed,
      // A refused send can't succeed on retry: the control removes it instead.
      onCancel: onDiscard,
      onRetry: rejected ? onDiscard : onRetry,
    );

    final doc = upload.doc;
    final video = upload.video;
    final photo = upload.photo;
    // Photos, videos and PDFs with a preview run edge to edge (as when sent).
    final bleed = photo != null || video != null || doc?.preview != null;
    final status = failed ? SendStatus.failed : SendStatus.sending;

    final Widget card;
    if (photo != null) {
      card = ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 340),
        child: SizedBox(
          width: 260,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.file(
                photo.file,
                width: 260,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => Container(
                      width: 260,
                      height: 180,
                      color: Colors.black26,
                    ),
              ),
              Positioned.fill(child: Center(child: ring(52))),
            ],
          ),
        ),
      );
    } else if (video != null) {
      card = VideoBubbleContent(
        mediaPath: null,
        durationMs: video.duration.inMilliseconds,
        sizeBytes: video.sizeBytes,
        width: video.width,
        height: video.height,
        localThumbnail: video.thumbnail,
        pending: ring,
        bleed: true,
      );
    } else {
      card = Padding(
        padding: EdgeInsets.only(bottom: bleed ? 24 : 0),
        child: FileBubbleContent(
          messageId: upload.id,
          mediaPath: null,
          fileName: doc!.fileName,
          mimeType: doc.mimeType,
          sizeBytes: doc.sizeBytes,
          pageCount: doc.pageCount,
          localPreview: doc.preview,
          foreground: c.onBubbleOut,
          pending: ring,
          bleed: doc.preview != null,
        ),
      );
    }

    final tick = MessageTicks(
      status: status,
      baseColor:
          (photo != null || video != null)
              ? Colors.white
              : c.onBubbleOut.withValues(alpha: 0.7),
      size: 16,
    );
    final caption = photo?.caption;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Align(
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              // Exactly the media width, so a long caption wraps underneath.
              constraints: BoxConstraints(
                maxWidth: bleed ? 260 : MediaQuery.sizeOf(context).width * 0.86,
              ),
              clipBehavior: Clip.antiAlias,
              padding:
                  bleed
                      ? EdgeInsets.zero
                      : const EdgeInsets.fromLTRB(13, 8, 11, 7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    c.bubbleOut.withValues(alpha: failed ? 0.6 : 1),
                    c.bubbleOutEnd.withValues(alpha: failed ? 0.6 : 1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              // Drawn over the content so edge-to-edge media can't cover the
              // border at the rounded corners.
              foregroundDecoration:
                  failed
                      ? BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: c.error, width: 1.5),
                      )
                      : null,
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        card,
                        if (photo != null || video != null)
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.42),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: tick,
                            ),
                          )
                        else if (doc?.preview != null)
                          Positioned(right: 11, bottom: 7, child: tick),
                      ],
                    ),
                    if (photo == null && video == null && doc?.preview == null)
                      Align(alignment: Alignment.centerRight, child: tick),
                    if (caption != null && caption.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(13, 7, 11, 7),
                        child: Text(
                          caption,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: c.onBubbleOut, height: 1.36),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (failed)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, size: 16, color: c.error),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      rejected ? l.sendRejected : l.fileSendFailed,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: c.error),
                    ),
                  ),
                  if (!rejected)
                    TextButton(onPressed: onRetry, child: Text(l.retry)),
                  TextButton(onPressed: onDiscard, child: Text(l.remove)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
