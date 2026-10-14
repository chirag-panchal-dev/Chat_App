import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/theme/hushlo_colors.dart';
import '../../../../core/widgets/hushlo_back_button.dart';
import '../viewmodels/attachment_view_model.dart';

/// Full-screen dark photo preview with a floating caption bar. "Sent" is only
/// reported once the message document has been committed (the screen pops
/// after `done`).
class AttachmentPreviewScreen extends ConsumerStatefulWidget {
  const AttachmentPreviewScreen({
    super.key,
    required this.conversationId,
    required this.path,
    this.replyToId,
  });

  final String conversationId;
  final String path;
  final String? replyToId;

  @override
  ConsumerState<AttachmentPreviewScreen> createState() =>
      _AttachmentPreviewScreenState();
}

class _AttachmentPreviewScreenState
    extends ConsumerState<AttachmentPreviewScreen> {
  final _caption = TextEditingController();

  static const _ink = Color(0xFF0A0F12);
  static const _panel = Color(0xFF161D22);

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  void _send() => ref
      .read(attachmentViewModelProvider(widget.conversationId).notifier)
      .send(
        File(widget.path),
        caption: _caption.text,
        replyToId: widget.replyToId,
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final id = widget.conversationId;
    final s = ref.watch(attachmentViewModelProvider(id));
    final vm = ref.read(attachmentViewModelProvider(id).notifier);
    final uploading = s.phase == AttachmentPhase.uploading;
    final failed = s.phase == AttachmentPhase.failed;

    ref.listen(attachmentViewModelProvider(id), (prev, next) {
      if (next.phase == AttachmentPhase.done && mounted) context.pop();
    });

    return PopScope(
      canPop: !uploading,
      child: Scaffold(
        backgroundColor: _ink,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: HushloBackButton(
            onDark: true,
            icon: Icons.close_rounded,
            tooltip: l.cancel,
            onPressed: () {
              if (uploading) vm.cancel();
              context.pop();
            },
          ),
          leadingWidth: 60,
          title: Text(
            l.sendPhoto,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                child: Center(
                  child: Image.file(File(widget.path), fit: BoxFit.contain),
                ),
              ),
            ),
            // Floating caption / send bar
            Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              decoration: const BoxDecoration(
                color: _ink,
                border: Border(top: BorderSide(color: Color(0xFF1F282E))),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (uploading)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                        child: Semantics(
                          label: l.uploading,
                          value: '${(s.progress * 100).round()}%',
                          child: Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: s.progress == 0 ? null : s.progress,
                                  minHeight: 5,
                                  borderRadius: BorderRadius.circular(4),
                                  backgroundColor: const Color(0xFF26313A),
                                  color: c.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${(s.progress * 100).round()}%',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (failed && s.failure != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: c.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                failureMessage(l, s.failure!),
                                style: TextStyle(
                                  color: c.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: _panel,
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: const Color(0xFF26313A),
                              ),
                            ),
                            child: TextField(
                              controller: _caption,
                              enabled: !uploading,
                              maxLength: AppConfig.maxCaptionLength,
                              maxLines: 4,
                              minLines: 1,
                              textCapitalization: TextCapitalization.sentences,
                              cursorColor: c.primary,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                hintText: l.captionHint,
                                hintStyle: const TextStyle(
                                  color: Color(0xFF8A99A3),
                                ),
                                counterText: '',
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (uploading)
                          SizedBox(
                            width: 52,
                            height: 52,
                            child: IconButton(
                              tooltip: l.cancel,
                              onPressed: vm.cancel,
                              style: IconButton.styleFrom(
                                backgroundColor: _panel,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          )
                        else
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [c.bubbleOut, c.bubbleOutEnd],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: IconButton(
                              tooltip:
                                  failed && s.failure is! PermissionFailure
                                      ? l.retry
                                      : l.send,
                              onPressed: _send,
                              color: Colors.white,
                              icon: Icon(
                                failed && s.failure is! PermissionFailure
                                    ? Icons.refresh_rounded
                                    : Icons.send_rounded,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
