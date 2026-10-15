import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/theme/hushlo_colors.dart';

/// The message bubble itself turned into a text field (like Teams): edit the
/// text in place, ✓ saves, ✕ cancels.
class InlineEditBubble extends StatefulWidget {
  const InlineEditBubble({
    super.key,
    required this.initialText,
    required this.onSave,
    required this.onCancel,
  });

  final String initialText;
  final ValueChanged<String> onSave;
  final VoidCallback onCancel;

  @override
  State<InlineEditBubble> createState() => _InlineEditBubbleState();
}

class _InlineEditBubbleState extends State<InlineEditBubble> {
  late final _controller = TextEditingController(text: widget.initialText);
  late bool _valid = widget.initialText.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.selection = TextSelection.collapsed(
      offset: widget.initialText.length,
    );
    _controller.addListener(() {
      final v = _controller.text.trim().isNotEmpty;
      if (v != _valid) setState(() => _valid = v);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final width = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: width * 0.86),
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 6),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.primary, width: 1.6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                minLines: 1,
                maxLines: 8,
                maxLength: AppConfig.maxMessageLength,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  counterText: '',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 6),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.editingMessage,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: l.cancelReply,
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onCancel,
                    icon: Icon(Icons.close_rounded, color: c.textSecondary),
                  ),
                  IconButton.filled(
                    tooltip: l.saveEdit,
                    visualDensity: VisualDensity.compact,
                    onPressed:
                        _valid ? () => widget.onSave(_controller.text) : null,
                    icon: const Icon(Icons.check_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
