import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../files/presentation/widgets/file_bubble_content.dart';
import '../../../files/presentation/widgets/video_bubble_content.dart';
import '../../../voice/presentation/widgets/voice_bubble_content.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/firebase/media_url_provider.dart';
import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/theme/hushlo_colors.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../attachments/data/image_processor.dart';
import '../../domain/entities/chat_message.dart';
import '../message_preview.dart';
import '../viewmodels/chat_view_model.dart';
import 'message_ticks.dart';

/// A chat bubble. Consecutive messages from the same sender are grouped: the
/// tail (sharp corner) and timestamp/ticks appear only on the last of a group.
/// Width of photo, video and PDF-preview content in a bubble.
const _mediaWidth = 260.0;

class MessageBubble extends ConsumerWidget {
  const MessageBubble({
    super.key,
    required this.conversationId,
    required this.message,
    required this.mine,
    required this.myUid,
    this.status,
    this.isGroupStart = true,
    this.isGroupEnd = true,
    this.replyTarget,
    this.onLongPress,
    this.onImageTap,
    this.onSwipeReply,
    this.onReplyTap,
    this.onReactionTap,
    this.senderName,
    this.avatarSlot,
  });

  final String conversationId;
  final ChatMessage message;
  final bool mine;
  final String myUid;

  /// Resolved status for my own messages (sent/delivered/read). Defaults to
  /// the message's stored status.
  final SendStatus? status;
  final bool isGroupStart;
  final bool isGroupEnd;
  final ChatMessage? replyTarget;
  final VoidCallback? onLongPress;
  final VoidCallback? onImageTap;
  final VoidCallback? onSwipeReply;

  /// Tap on the quoted message: jump to the original.
  final VoidCallback? onReplyTap;

  /// Tap on a reaction chip with that emoji (toggles my reaction).
  final ValueChanged<String>? onReactionTap;

  /// Group chats: sender name shown above the first bubble of a run.
  final String? senderName;

  /// Group chats: avatar column on the left of incoming bubbles.
  final Widget? avatarSlot;

  /// Group chats put a small avatar column to the left of incoming bubbles.
  Widget _withAvatar(Widget bubble) {
    final slot = avatarSlot;
    if (slot == null) return bubble;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [SizedBox(width: 38, child: slot), Flexible(child: bubble)],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final fg = mine ? c.onBubbleOut : c.onBubbleIn;
    final maxW =
        MediaQuery.sizeOf(context).width * 0.78 - (avatarSlot != null ? 40 : 0);
    final locale = Localizations.localeOf(context).toString();
    final reactions =
        ref
            .watch(reactionsProvider((cid: conversationId, mid: message.id)))
            .value ??
        const {};

    const big = Radius.circular(20);
    const small = Radius.circular(5);
    final radius = BorderRadius.only(
      topLeft: !mine && !isGroupStart ? small : big,
      topRight: mine && !isGroupStart ? small : big,
      bottomLeft: !mine && isGroupEnd ? small : (!mine ? small : big),
      bottomRight: mine && isGroupEnd ? small : (mine ? small : big),
    );

    final timeStyle = TextStyle(
      fontFamily: 'Inter',
      fontSize: 11.5,
      fontWeight: FontWeight.w500,
      color: fg.withValues(alpha: 0.7),
    );
    final timeText =
        message.edited
            ? '${context.l10n.editedLabel} · ${DateFormatter.time(message.createdAt, locale)}'
            : DateFormatter.time(message.createdAt, locale);
    final metaStatus = status ?? message.status;
    final meta = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(timeText, style: timeStyle),
        if (mine) ...[
          const SizedBox(width: 3),
          MessageTicks(
            status: metaStatus,
            baseColor: fg.withValues(alpha: 0.7),
            size: 16,
          ),
        ],
      ],
    );
    // Time and ticks on a dark pill, drawn over photos and videos.
    Widget metaPill() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(timeText, style: timeStyle.copyWith(color: Colors.white)),
          if (mine) ...[
            const SizedBox(width: 3),
            MessageTicks(status: metaStatus, baseColor: Colors.white, size: 15),
          ],
        ],
      ),
    );

    // Width the inline meta needs, so the last text line leaves room for it.
    final tp = TextPainter(
      text: TextSpan(text: timeText, style: timeStyle),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final metaWidth = tp.width + (mine ? 22 : 0) + 8;

    final hasText = !message.deleted && (message.text ?? '').isNotEmpty;
    // Photos, videos and PDFs with a preview fill the bubble edge to edge.
    final bleed =
        !message.deleted &&
        (message.isImage ||
            message.isVideo ||
            (message.isFile && message.thumbnailPath != null));
    final imageOnly = !message.deleted && message.isImage && !hasText;
    final bodyStyle = Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(color: fg, height: 1.36, fontSize: 16);

    final bubble = Container(
      // Media bubbles are exactly as wide as the media (260): a long caption
      // wraps underneath instead of stretching the bubble.
      constraints: BoxConstraints(
        maxWidth: bleed ? (maxW < _mediaWidth ? maxW : _mediaWidth) : maxW,
      ),
      decoration: BoxDecoration(
        gradient:
            mine
                ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [c.bubbleOut, c.bubbleOutEnd],
                )
                : null,
        color: mine ? null : c.bubbleIn,
        borderRadius: radius,
        border:
            (mine || bleed)
                ? null
                : Border.all(
                  color: c.outline.withValues(alpha: 0.7),
                  width: 0.8,
                ),
        boxShadow: [
          BoxShadow(
            color: (mine ? c.bubbleOutEnd : Colors.black).withValues(
              alpha: mine ? 0.22 : 0.04,
            ),
            blurRadius: mine ? 8 : 3,
            offset: Offset(0, mine ? 3 : 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      // Incoming media bubbles: outline drawn over the edge-to-edge content.
      foregroundDecoration:
          (bleed && !mine)
              ? BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: c.outline.withValues(alpha: 0.7),
                  width: 0.8,
                ),
              )
              : null,
      padding:
          bleed ? EdgeInsets.zero : const EdgeInsets.fromLTRB(13, 8, 11, 7),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (senderName != null && !mine)
              Padding(
                padding:
                    bleed
                        ? const EdgeInsets.fromLTRB(13, 8, 11, 3)
                        : const EdgeInsets.only(bottom: 3),
                child: Text(
                  senderName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? avatarGradient(senderName!).first
                            : avatarGradient(senderName!).last,
                  ),
                ),
              ),
            if (message.deleted)
              Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(
                                Icons.block_rounded,
                                size: 15,
                                color: fg.withValues(alpha: 0.65),
                              ),
                            ),
                          ),
                          TextSpan(
                            text:
                                mine
                                    ? context.l10n.youDeletedMessage
                                    : context.l10n.messageDeleted,
                            style: bodyStyle?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: fg.withValues(alpha: 0.72),
                              fontSize: 15,
                            ),
                          ),
                          WidgetSpan(
                            child: SizedBox(width: metaWidth, height: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(right: 0, bottom: 0, child: meta),
                ],
              ),
            if (!message.deleted && message.replyToId != null)
              Padding(
                padding: bleed ? const EdgeInsets.all(6) : EdgeInsets.zero,
                child: _ReplyQuote(
                  target: replyTarget,
                  mine: mine,
                  onTap: onReplyTap,
                ),
              ),
            if (!message.deleted && message.isImage)
              Stack(
                children: [
                  _ImageContent(message: message, onTap: onImageTap),
                  if (imageOnly)
                    Positioned(right: 8, bottom: 8, child: metaPill()),
                ],
              ),
            if (!message.deleted && message.isVoice)
              Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: VoiceBubbleContent(
                      messageId: message.id,
                      mediaPath: message.mediaPath,
                      durationMs: message.durationMs ?? 0,
                      waveform: message.waveform ?? const [],
                      foreground: fg,
                    ),
                  ),
                  Positioned(right: 0, bottom: 0, child: meta),
                ],
              ),
            if (!message.deleted && message.isVideo)
              Stack(
                children: [
                  VideoBubbleContent(
                    mediaPath: message.mediaPath,
                    durationMs: message.durationMs ?? 0,
                    sizeBytes: message.sizeBytes,
                    width: message.width,
                    height: message.height,
                    thumbnailPath: message.thumbnailPath,
                    bleed: true,
                  ),
                  Positioned(right: 8, bottom: 8, child: metaPill()),
                ],
              ),
            if (!message.deleted && message.isFile)
              Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: message.thumbnailPath != null ? 24 : 18,
                    ),
                    child: FileBubbleContent(
                      messageId: message.id,
                      mediaPath: message.mediaPath,
                      fileName: message.fileName ?? context.l10n.document,
                      mimeType: message.mimeType,
                      sizeBytes: message.sizeBytes,
                      foreground: fg,
                      thumbnailPath: message.thumbnailPath,
                      pageCount: message.pageCount,
                      bleed: message.thumbnailPath != null,
                    ),
                  ),
                  Positioned(
                    right: message.thumbnailPath != null ? 11 : 0,
                    bottom: message.thumbnailPath != null ? 7 : 0,
                    child: meta,
                  ),
                ],
              ),
            if (hasText)
              Padding(
                padding:
                    message.isImage
                        ? const EdgeInsets.fromLTRB(13, 7, 11, 7)
                        : EdgeInsets.zero,
                child: Stack(
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: message.text!, style: bodyStyle),
                          WidgetSpan(
                            child: SizedBox(width: metaWidth, height: 14),
                          ),
                        ],
                      ),
                    ),
                    Positioned(right: 0, bottom: 0, child: meta),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    Widget content = GestureDetector(
      onLongPress:
          onLongPress == null
              ? null
              : () {
                HapticFeedback.selectionClick();
                onLongPress!();
              },
      child: bubble,
    );
    if (onSwipeReply != null) {
      content = _SwipeToReply(onReply: onSwipeReply!, child: content);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(12, isGroupStart ? 6 : 1.5, 12, 0),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: _withAvatar(
          Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              content,
              if (!message.deleted && reactions.isNotEmpty)
                Transform.translate(
                  offset: const Offset(0, -6),
                  child: _ReactionChips(
                    reactions: reactions,
                    myUid: myUid,
                    onTap: onReactionTap,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Drag a bubble sideways to reply (WhatsApp/Telegram pattern).
class _SwipeToReply extends StatefulWidget {
  const _SwipeToReply({required this.child, required this.onReply});
  final Widget child;
  final VoidCallback onReply;

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> {
  double _dx = 0;
  bool _fired = false;
  static const _trigger = 56.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final progress = (_dx / _trigger).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (d) {
        setState(() => _dx = (_dx + d.delta.dx).clamp(0.0, 80.0));
        if (_dx >= _trigger && !_fired) {
          _fired = true;
          HapticFeedback.lightImpact();
        }
      },
      onHorizontalDragEnd: (_) {
        if (_fired) widget.onReply();
        setState(() {
          _dx = 0;
          _fired = false;
        });
      },
      onHorizontalDragCancel:
          () => setState(() {
            _dx = 0;
            _fired = false;
          }),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned(
            left: 4,
            child: Opacity(
              opacity: progress,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c.surfaceSubtle,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.reply_rounded, size: 18, color: c.primary),
              ),
            ),
          ),
          Transform.translate(offset: Offset(_dx, 0), child: widget.child),
        ],
      ),
    );
  }
}

class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({required this.target, required this.mine, this.onTap});
  final ChatMessage? target;
  final bool mine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final fg = mine ? c.onBubbleOut : c.onBubbleIn;
    return Semantics(
      button: onTap != null,
      label: l.goToOriginal,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: fg.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: mine ? c.tickRead : c.accent,
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                target?.preview(l) ?? l.originalUnavailable,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: fg.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReactionChips extends StatelessWidget {
  const _ReactionChips({
    required this.reactions,
    required this.myUid,
    this.onTap,
  });
  final Map<String, String> reactions;
  final String myUid;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final counts = <String, int>{};
    for (final e in reactions.values) {
      counts[e] = (counts[e] ?? 0) + 1;
    }
    return Wrap(
      spacing: 4,
      children: [
        for (final e in counts.entries)
          Builder(
            builder: (context) {
              final mineChip = reactions[myUid] == e.key;
              return Semantics(
                button: true,
                label:
                    mineChip
                        ? '${l.removeReaction} ${e.key}'
                        : '${l.react} ${e.key}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onTap == null ? null : () => onTap!(e.key),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 26),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: mineChip ? c.primaryContainer : c.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: mineChip ? c.primary : c.outline,
                        width: mineChip ? 1.3 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    child: Text(
                      e.value > 1 ? '${e.key} ${e.value}' : e.key,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            mineChip ? FontWeight.w700 : FontWeight.w500,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _ImageContent extends ConsumerWidget {
  const _ImageContent({required this.message, this.onTap});
  final ChatMessage message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.colors;
    final path = message.thumbnailPath ?? message.mediaPath;
    final aspect = clampedAspect(message.width, message.height);

    // The bubble itself clips the corners (photos are edge to edge).
    Widget frame(Widget child) =>
        AspectRatio(aspectRatio: aspect, child: child);

    Widget placeholder({bool error = false, VoidCallback? retry}) => Container(
      color: c.surfaceSubtle,
      alignment: Alignment.center,
      child:
          error
              ? TextButton.icon(
                onPressed: retry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l.retry),
              )
              : const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
    );

    if (path == null) {
      return SizedBox(width: 260, child: frame(placeholder(error: true)));
    }
    final url = ref.watch(mediaUrlProvider(path));
    return Semantics(
      button: true,
      image: true,
      label: l.photo,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 260,
          child: frame(
            url.when(
              data:
                  (u) => CachedNetworkImage(
                    imageUrl: u,
                    cacheKey: path,
                    fit: BoxFit.cover,
                    memCacheWidth: 520,
                    placeholder: (_, __) => placeholder(),
                    errorWidget:
                        (_, __, ___) => placeholder(
                          error: true,
                          retry: () => ref.invalidate(mediaUrlProvider(path)),
                        ),
                  ),
              loading: placeholder,
              error:
                  (e, __) => placeholder(
                    error: Failure.from(e) is! PermissionFailure,
                    retry: () => ref.invalidate(mediaUrlProvider(path)),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A text message that failed to send: shows why and offers retry / remove.
class FailedBubble extends StatelessWidget {
  const FailedBubble({
    super.key,
    required this.failed,
    required this.onRetry,
    required this.onDiscard,
  });

  final FailedMessage failed;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final canRetry = failed.failure is! PermissionFailure;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Align(
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.78,
              ),
              padding: const EdgeInsets.fromLTRB(13, 9, 13, 9),
              decoration: BoxDecoration(
                color: c.bubbleOut.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.error, width: 1.5),
              ),
              child: Text(
                failed.text,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: c.onBubbleOut),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 16, color: c.error),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    failed.failure is PermissionFailure
                        ? l.sendRejected
                        : l.sendFailed,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: c.error),
                  ),
                ),
                if (canRetry)
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
