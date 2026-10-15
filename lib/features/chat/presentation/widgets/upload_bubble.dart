import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/theme/hushlo_colors.dart';

/// A voice note, document or video being uploaded (progress + cancel) or
/// that failed (retry).
class UploadBubble extends StatelessWidget {
  const UploadBubble({
    super.key,
    required this.label,
    this.icon = Icons.mic_rounded,
    required this.progress,
    required this.failed,
    required this.rejected,
    required this.onRetry,
    required this.onDiscard,
  });

  final String label;
  final IconData icon;
  final double progress;
  final bool failed;

  /// Server refused it (retrying would not help).
  final bool rejected;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Align(
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.86,
              ),
              padding: const EdgeInsets.fromLTRB(13, 10, 8, 10),
              decoration: BoxDecoration(
                color: c.bubbleOut.withValues(alpha: failed ? 0.55 : 0.8),
                borderRadius: BorderRadius.circular(20),
                border: failed ? Border.all(color: c.error, width: 1.5) : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child:
                        failed
                            ? Icon(icon, color: c.onBubbleOut)
                            : CircularProgressIndicator(
                              strokeWidth: 2.4,
                              value: progress > 0 ? progress : null,
                              color: c.onBubbleOut,
                            ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.onBubbleOut,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l.voiceCancel,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close_rounded, color: c.onBubbleOut),
                    onPressed: onDiscard,
                  ),
                ],
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
                      rejected ? l.sendRejected : l.voiceSendFailed,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: c.error),
                    ),
                  ),
                  if (!rejected)
                    TextButton(onPressed: onRetry, child: Text(l.retry)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
