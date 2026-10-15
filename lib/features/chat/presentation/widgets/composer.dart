import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/theme/hushlo_colors.dart';
import '../../../voice/domain/voice_models.dart';
import '../../../voice/presentation/viewmodels/voice_recorder_controller.dart';
import '../../../voice/presentation/widgets/waveform_view.dart';
import '../../domain/entities/chat_message.dart';
import '../message_preview.dart';

/// Persistent composer: attach, multiline text, send. Send is enabled only
/// when the trimmed text is non-empty.
class Composer extends ConsumerStatefulWidget {
  const Composer({
    super.key,
    required this.onSend,
    required this.onAttach,
    this.replyTo,
    this.onCancelReply,
    this.onChanged,
    this.conversationId,
    this.onVoice,
  });

  /// With [onVoice], an empty composer shows a mic (hold or tap to record).
  final String? conversationId;
  final ValueChanged<VoiceRecording>? onVoice;

  /// Returns true if the text was accepted (the field is then cleared).
  final bool Function(String text) onSend;
  final VoidCallback onAttach;
  final ChatMessage? replyTo;
  final VoidCallback? onCancelReply;

  /// Called with the current text on every change (typing indicator).
  final ValueChanged<String>? onChanged;

  @override
  ConsumerState<Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<Composer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      widget.onChanged?.call(_controller.text);
      final can = _controller.text.trim().isNotEmpty;
      if (can != _canSend) setState(() => _canSend = can);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool get _voiceEnabled =>
      widget.onVoice != null && widget.conversationId != null;

  VoiceRecorderController get _rec =>
      ref.read(voiceRecorderProvider(widget.conversationId!).notifier);

  Future<void> _startRecording({required bool locked}) async {
    HapticFeedback.mediumImpact();
    await _rec.start(locked: locked);
  }

  Future<void> _sendRecording() async {
    final r = await _rec.finish();
    if (r != null) widget.onVoice!(r);
  }

  void _voiceDrag(LongPressMoveUpdateDetails d) {
    final o = d.offsetFromOrigin;
    if (o.dy < -70) {
      HapticFeedback.selectionClick();
      _rec.lock();
    } else {
      _rec.setCancelling(o.dx < -90);
    }
  }

  Future<void> _voiceRelease() async {
    final st = ref.read(voiceRecorderProvider(widget.conversationId!));
    if (st.phase != RecorderPhase.holding) return; // locked: stays open
    if (st.cancelling) {
      await _rec.cancel();
    } else {
      await _sendRecording();
    }
  }

  void _send() {
    if (!_canSend) return;
    if (widget.onSend(_controller.text)) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final reply = widget.replyTo;
    final rec =
        _voiceEnabled
            ? ref.watch(voiceRecorderProvider(widget.conversationId!))
            : const VoiceRecorderState();
    if (_voiceEnabled) {
      ref.listen(voiceRecorderProvider(widget.conversationId!), (prev, next) {
        final e = next.error;
        if (e == null || e == prev?.error) return;
        final msg = switch (e) {
          VoiceRecordError.permissionDenied => l.voiceMicDenied,
          VoiceRecordError.tooShort => l.voiceTooShort,
          VoiceRecordError.failed => l.voiceFailed,
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
        _rec.clearError();
      });
    }
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reply != null)
              Container(
                margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border(left: BorderSide(color: c.accent, width: 3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        reply.preview(l),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      tooltip: l.cancelReply,
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: widget.onCancelReply,
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child:
                        rec.isRecording
                            ? _RecordingField(state: rec, onCancel: _rec.cancel)
                            : Container(
                              decoration: BoxDecoration(
                                color: c.surface,
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  IconButton(
                                    tooltip: l.attachPhoto,
                                    onPressed: widget.onAttach,
                                    icon: Icon(
                                      Icons.add_circle_outline_rounded,
                                      color: c.primary,
                                      size: 28,
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _controller,
                                      focusNode: _focus,
                                      minLines: 1,
                                      maxLines: 5,
                                      maxLength: AppConfig.maxMessageLength,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      keyboardType: TextInputType.multiline,
                                      decoration: InputDecoration(
                                        hintText: l.messageHint,
                                        counterText: '',
                                        filled: false,
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 14,
                                              horizontal: 0,
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                              ),
                            ),
                  ),
                  const SizedBox(width: 8),
                  if (rec.phase == RecorderPhase.locked)
                    _SendRecordingButton(
                      tooltip: l.voiceSendTooltip,
                      onPressed: _sendRecording,
                    )
                  else if (_voiceEnabled && (!_canSend || rec.isRecording))
                    _MicButton(
                      recording: rec.isRecording,
                      cancelling: rec.cancelling,
                      tooltip: l.voiceMicTooltip,
                      onTap: () => _startRecording(locked: true),
                      onHoldStart: () => _startRecording(locked: false),
                      onMove: _voiceDrag,
                      onRelease: _voiceRelease,
                    )
                  else
                    AnimatedScale(
                      scale: _canSend ? 1 : 0.9,
                      duration: const Duration(milliseconds: 120),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient:
                              _canSend
                                  ? LinearGradient(
                                    colors: [c.bubbleOut, c.bubbleOutEnd],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                  : null,
                          color: _canSend ? null : c.surfaceSubtle,
                        ),
                        child: IconButton(
                          tooltip: l.send,
                          onPressed: _canSend ? _send : null,
                          icon: const Icon(Icons.send_rounded),
                          color: Colors.white,
                          disabledColor: c.textSecondary,
                          iconSize: 24,
                          constraints: const BoxConstraints(
                            minWidth: 52,
                            minHeight: 52,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.recording,
    required this.cancelling,
    required this.tooltip,
    required this.onTap,
    required this.onHoldStart,
    required this.onMove,
    required this.onRelease,
  });

  final bool recording;
  final bool cancelling;
  final String tooltip;
  final VoidCallback onTap;
  final VoidCallback onHoldStart;
  final ValueChanged<LongPressMoveUpdateDetails> onMove;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        onTap: onTap,
        onLongPressStart: (_) => onHoldStart(),
        onLongPressMoveUpdate: onMove,
        onLongPressEnd: (_) => onRelease(),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cancelling ? c.error : null,
            gradient:
                cancelling
                    ? null
                    : LinearGradient(
                      colors: [c.bubbleOut, c.bubbleOutEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
          ),
          child: Icon(
            cancelling ? Icons.delete_rounded : Icons.mic_rounded,
            color: Colors.white,
            size: recording ? 30 : 26,
          ),
        ),
      ),
    );
  }
}

/// Replaces the text field while recording: timer, live level bars, and
/// "slide to cancel" (holding) or cancel/send buttons (locked).
class _RecordingField extends StatelessWidget {
  const _RecordingField({required this.state, required this.onCancel});

  final VoiceRecorderState state;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final locked = state.phase == RecorderPhase.locked;
    final bars =
        state.levels
            .map((db) => (((db.clamp(-50.0, 0.0) + 50) / 50) * 100).round())
            .toList();
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: state.cancelling ? c.error.withValues(alpha: 0.12) : c.surface,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          if (locked)
            IconButton(
              tooltip: l.voiceCancel,
              onPressed: onCancel,
              icon: Icon(Icons.delete_outline_rounded, color: c.error),
            )
          else
            const SizedBox(width: 10),
          Icon(Icons.fiber_manual_record, color: c.error, size: 14),
          const SizedBox(width: 6),
          Text(
            formatVoiceDuration(state.elapsedMs),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                locked || state.levels.length > 6
                    ? WaveformView(
                      bars:
                          bars.length > 28
                              ? bars.sublist(bars.length - 28)
                              : bars,
                      progress: 1,
                      playedColor: c.primary,
                      idleColor: c.primary,
                      height: 26,
                    )
                    : const SizedBox.shrink(),
          ),
          if (!locked)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                state.cancelling ? l.voiceCancel : '‹ ${l.voiceSlideCancel}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: state.cancelling ? c.error : c.textSecondary,
                ),
              ),
            ),
          if (state.reachedLimit)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('5:00', style: TextStyle(color: c.error)),
            ),
        ],
      ),
    );
  }
}

class _SendRecordingButton extends StatelessWidget {
  const _SendRecordingButton({required this.tooltip, required this.onPressed});
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [c.bubbleOut, c.bubbleOutEnd]),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: const Icon(Icons.send_rounded, color: Colors.white),
        constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
      ),
    );
  }
}
