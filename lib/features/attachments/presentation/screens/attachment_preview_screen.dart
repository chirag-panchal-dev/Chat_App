import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/theme/hushlo_colors.dart';
import '../../../../core/widgets/hushlo_back_button.dart';
import '../../../chat/presentation/viewmodels/chat_view_model.dart';
import '../../../files/domain/picked_media.dart';

/// Full-screen dark photo preview with a floating caption bar. Send returns to
/// the chat right away; the photo uploads there with a progress ring (and a
/// retry control if it fails), like documents and videos.
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

  void _send() {
    ref
        .read(chatViewModelProvider(widget.conversationId).notifier)
        .sendPhoto(
          PickedPhoto(file: File(widget.path), caption: _caption.text.trim()),
          replyToId: widget.replyToId,
        );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;

    return Scaffold(
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
          onPressed: () => context.pop(),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: _panel,
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(color: const Color(0xFF26313A)),
                          ),
                          child: TextField(
                            controller: _caption,
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
                          tooltip: l.send,
                          onPressed: _send,
                          color: Colors.white,
                          icon: const Icon(Icons.send_rounded),
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
    );
  }
}
