import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_ext.dart';
import '../../../voice/domain/voice_models.dart';
import '../../domain/file_rules.dart';
import 'preview_image.dart';

/// Video card: dark frame sized from the video's width/height with a play
/// button, length and size. Tap opens the full-screen player.
class VideoBubbleContent extends StatelessWidget {
  const VideoBubbleContent({
    super.key,
    required this.mediaPath,
    required this.durationMs,
    required this.sizeBytes,
    this.width,
    this.height,
    this.thumbnailPath,
    this.localThumbnail,
    this.pending,
    this.bleed = false,
  });

  /// Edge-to-edge inside a bubble that already clips its own corners.
  final bool bleed;

  /// Not yet uploaded: show this local frame instead of the network thumbnail.
  final File? localThumbnail;

  /// While uploading / failed: control shown instead of the play button; the
  /// card is not tappable then.
  final Widget Function(double size)? pending;

  final String? mediaPath;
  final int durationMs;
  final int? sizeBytes;
  final int? width;
  final int? height;
  final String? thumbnailPath;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final aspect =
        (width != null && height != null && width! > 0 && height! > 0)
            ? (width! / height!).clamp(0.6, 1.8)
            : 16 / 9;
    return Semantics(
      button: true,
      label: '${l.video} ${formatVoiceDuration(durationMs)}',
      child: InkWell(
        onTap:
            (mediaPath == null || pending != null)
                ? null
                : () => context.push(
                  '/video',
                  extra: {'path': mediaPath, 'durationMs': durationMs},
                ),
        borderRadius: bleed ? null : BorderRadius.circular(14),
        child: SizedBox(
          width: bleed ? 260 : 240,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(bleed ? 0 : 14),
            child: AspectRatio(
              aspectRatio: aspect.toDouble(),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF263238), Color(0xFF0F171B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  fit: StackFit.expand,
                  children: [
                    if (localThumbnail != null)
                      Image.file(
                        localThumbnail!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      )
                    else if (thumbnailPath != null)
                      PreviewImage(
                        path: thumbnailPath!,
                        fallback: const SizedBox.shrink(),
                      ),
                    if (thumbnailPath != null || localThumbnail != null)
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Color(0x66000000)],
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    if (pending != null)
                      Center(child: pending!(54))
                    else
                      Center(
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.2),
                            border: Border.all(
                              color: Colors.white70,
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                      ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.videocam_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              [
                                formatVoiceDuration(durationMs),
                                if (sizeBytes != null)
                                  formatFileSize(sizeBytes!),
                              ].join(' · '),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
