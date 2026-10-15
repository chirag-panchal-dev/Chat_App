import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_ext.dart';

/// WhatsApp-style control over a file that is still uploading: a progress ring
/// with ✕ (tap to cancel), or a ↻ (tap to retry) once the upload failed.
class PendingRing extends StatelessWidget {
  const PendingRing({
    super.key,
    this.size = 52,
    required this.progress,
    required this.failed,
    required this.onCancel,
    required this.onRetry,
  });

  final double size;
  final double progress;
  final bool failed;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Semantics(
      button: true,
      label: failed ? l.retry : l.voiceCancel,
      child: GestureDetector(
        onTap: failed ? onRetry : onCancel,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.55),
            border:
                failed ? Border.all(color: Colors.redAccent, width: 1.5) : null,
          ),
          alignment: Alignment.center,
          child:
              failed
                  ? Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: size * 0.5,
                  )
                  : Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: size - 8,
                        height: size - 8,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          value: progress > 0 ? progress : null,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: size * 0.4,
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}
