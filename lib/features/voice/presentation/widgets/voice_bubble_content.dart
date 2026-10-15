import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/media_url_provider.dart';
import '../../../../core/l10n/l10n_ext.dart';
import '../../domain/voice_models.dart';
import '../../domain/voice_player.dart';
import '../viewmodels/voice_player_controller.dart';
import 'waveform_view.dart';

/// Play/pause, waveform with progress and a speed pill, for a voice message.
class VoiceBubbleContent extends ConsumerWidget {
  const VoiceBubbleContent({
    super.key,
    required this.messageId,
    required this.mediaPath,
    required this.durationMs,
    required this.waveform,
    required this.foreground,
  });

  final String messageId;
  final String? mediaPath;
  final int durationMs;
  final List<int> waveform;
  final Color foreground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final player = ref.watch(voicePlayerControllerProvider);
    final ctl = ref.read(voicePlayerControllerProvider.notifier);
    final active = player.isActive(messageId);
    final playing = player.isPlaying(messageId);
    final loading = active && player.status == VoicePlaybackStatus.loading;
    final failed = active && player.status == VoicePlaybackStatus.error;
    final fraction = player.fraction(messageId);
    final shown =
        active && player.position > Duration.zero
            ? player.position.inMilliseconds
            : durationMs;

    Future<void> toggle() async {
      final path = mediaPath;
      if (path == null) return;
      try {
        final url = await ref.read(mediaUrlProvider(path).future);
        await ctl.toggle(
          messageId,
          url,
          knownDuration: Duration(milliseconds: durationMs),
        );
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l.voicePlayError)));
        }
      }
    }

    return SizedBox(
      width: 230,
      child: Row(
        children: [
          Semantics(
            button: true,
            label: playing ? l.voicePauseTooltip : l.voicePlayTooltip,
            child: InkResponse(
              onTap: loading ? null : toggle,
              radius: 26,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: foreground.withValues(alpha: 0.18),
                ),
                child:
                    loading
                        ? Padding(
                          padding: const EdgeInsets.all(11),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: foreground,
                          ),
                        )
                        : Icon(
                          failed
                              ? Icons.refresh_rounded
                              : playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: foreground,
                          size: 26,
                        ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutBuilder(
                  builder:
                      (ctx, box) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragUpdate:
                            active
                                ? (d) => ctl.seekFraction(
                                  messageId,
                                  d.localPosition.dx / box.maxWidth,
                                )
                                : null,
                        onTapDown:
                            active
                                ? (d) => ctl.seekFraction(
                                  messageId,
                                  d.localPosition.dx / box.maxWidth,
                                )
                                : null,
                        child: WaveformView(
                          bars: waveform,
                          progress: fraction,
                          playedColor: foreground,
                          idleColor: foreground.withValues(alpha: 0.38),
                        ),
                      ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      formatVoiceDuration(shown),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: foreground.withValues(alpha: 0.8),
                      ),
                    ),
                    if (active && playing) ...[
                      const SizedBox(width: 8),
                      Semantics(
                        button: true,
                        label: l.voiceSpeedTooltip,
                        child: GestureDetector(
                          onTap: ctl.cycleSpeed,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: foreground.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${player.speed == player.speed.roundToDouble() ? player.speed.toInt() : player.speed}x',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: foreground,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
