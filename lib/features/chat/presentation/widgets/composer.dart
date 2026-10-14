import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/theme/hushlo_colors.dart';
import '../../domain/entities/chat_message.dart';

/// Persistent composer: attach, multiline text, send. Send is enabled only
/// when the trimmed text is non-empty.
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.onSend,
    required this.onAttach,
    this.replyTo,
    this.onCancelReply,
    this.onChanged,
  });

  /// Returns true if the text was accepted (the field is then cleared).
  final bool Function(String text) onSend;
  final VoidCallback onAttach;
  final ChatMessage? replyTo;
  final VoidCallback? onCancelReply;

  /// Called with the current text on every change (typing indicator).
  final ValueChanged<String>? onChanged;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _controller = TextEditingController();
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
    _controller.dispose();
    super.dispose();
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
                        reply.previewText(l.photo),
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
                    child: Container(
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
                              minLines: 1,
                              maxLines: 5,
                              maxLength: AppConfig.maxMessageLength,
                              textCapitalization: TextCapitalization.sentences,
                              keyboardType: TextInputType.multiline,
                              decoration: InputDecoration(
                                hintText: l.messageHint,
                                counterText: '',
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
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
