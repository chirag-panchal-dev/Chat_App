import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/media_url_provider.dart';
import '../../../../core/l10n/l10n_ext.dart';
import '../../domain/file_rules.dart';
import '../viewmodels/file_providers.dart';
import 'preview_image.dart';

/// (icon colour, label) for a file extension.
({Color color, String label}) fileKind(String name) => switch (fileExtension(
  name,
)) {
  'pdf' => (color: const Color(0xFFE5484D), label: 'PDF'),
  'doc' || 'docx' => (color: const Color(0xFF2F6FDE), label: 'DOC'),
  'xls' || 'xlsx' || 'csv' => (color: const Color(0xFF2FA36B), label: 'XLS'),
  'ppt' || 'pptx' => (color: const Color(0xFFEF8A3C), label: 'PPT'),
  'zip' => (color: const Color(0xFF8A94A6), label: 'ZIP'),
  _ => (color: const Color(0xFF7C8A94), label: 'TXT'),
};

/// Document card: type badge, file name and size. Tap downloads the file and
/// opens the system share sheet.
class FileBubbleContent extends ConsumerStatefulWidget {
  const FileBubbleContent({
    super.key,
    required this.messageId,
    required this.mediaPath,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.foreground,
    this.thumbnailPath,
    this.pageCount,
    this.localPreview,
    this.pending,
    this.bleed = false,
  });

  /// With a preview: the preview runs edge to edge across the top of the
  /// bubble (which clips its own corners) and the text row is padded.
  final bool bleed;

  /// Not yet uploaded: show this local image instead of the network preview.
  final File? localPreview;

  /// While uploading / failed: builds the control (progress ring, retry) shown
  /// over the preview, or in place of the badge when there is no preview. The
  /// card is not tappable then.
  final Widget Function(double size)? pending;

  final String messageId;
  final String? mediaPath;
  final String fileName;
  final String? mimeType;
  final int? sizeBytes;
  final Color foreground;
  final String? thumbnailPath;
  final int? pageCount;

  @override
  ConsumerState<FileBubbleContent> createState() => _FileBubbleContentState();
}

class _FileBubbleContentState extends ConsumerState<FileBubbleContent> {
  bool _busy = false;

  Future<void> _open() async {
    final path = widget.mediaPath;
    if (path == null || _busy) return;
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      final url = await ref.read(mediaUrlProvider(path).future);
      await ref
          .read(fileOpenerProvider)
          .open(
            url: url,
            messageId: widget.messageId,
            fileName: widget.fileName,
            mimeType: widget.mimeType ?? 'application/octet-stream',
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.fileOpenFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _previewFallback(Color fg) => Container(
    color: Colors.white.withValues(alpha: 0.12),
    alignment: Alignment.center,
    child: Icon(
      Icons.picture_as_pdf_rounded,
      size: 40,
      color: fg.withValues(alpha: 0.6),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final kind = fileKind(widget.fileName);
    final fg = widget.foreground;
    final size = widget.sizeBytes;
    final ext = fileExtension(widget.fileName).toUpperCase();
    // "12 pages · 2.3 MB · PDF"
    final details = [
      if (widget.pageCount != null) l.pagesCount(widget.pageCount!),
      if (size != null) formatFileSize(size),
      if (ext.isNotEmpty) ext,
    ].join(' · ');
    final thumb = widget.thumbnailPath;
    final hasPreview = thumb != null || widget.localPreview != null;
    final pending = widget.pending;
    final badge = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: kind.color,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child:
          (pending != null && !hasPreview)
              ? pending(36)
              : _busy
              ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
              : Text(
                kind.label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
    );
    return Semantics(
      button: true,
      label: '${l.document} ${widget.fileName}',
      child: InkWell(
        onTap: pending != null ? null : _open,
        borderRadius: widget.bleed ? null : BorderRadius.circular(12),
        child: SizedBox(
          width: widget.bleed ? 260 : 240,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasPreview)
                Padding(
                  padding: EdgeInsets.only(bottom: widget.bleed ? 0 : 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(widget.bleed ? 0 : 10),
                    child: SizedBox(
                      height: widget.bleed ? 180 : 150,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        alignment: Alignment.center,
                        children: [
                          if (widget.localPreview != null)
                            Image.file(
                              widget.localPreview!,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              errorBuilder:
                                  (_, __, ___) => _previewFallback(fg),
                            )
                          else
                            PreviewImage(
                              path: thumb!,
                              alignment: Alignment.topCenter,
                              fallback: _previewFallback(fg),
                            ),
                          if (pending != null) Center(child: pending(52)),
                        ],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding:
                    widget.bleed
                        ? const EdgeInsets.fromLTRB(11, 9, 11, 0)
                        : EdgeInsets.zero,
                child: Row(
                  children: [
                    badge,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.fileName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: fg,
                            ),
                          ),
                          if (details.isNotEmpty)
                            Text(
                              details,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: fg.withValues(alpha: 0.75),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
