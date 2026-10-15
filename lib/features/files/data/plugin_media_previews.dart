import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../domain/media_previews.dart';

/// pdfx renders page 1 (Android PdfRenderer / iOS PDFKit); video_thumbnail
/// grabs a frame. Every failure degrades to "no preview", never to an error.
class PluginMediaPreviews implements MediaPreviews {
  static const _maxPreviewWidth = 640.0;

  Future<File> _tmp(String ext) async {
    final dir = await getTemporaryDirectory();
    return File(p.join(dir.path, 'preview_${const Uuid().v4()}.$ext'));
  }

  @override
  Future<PdfInfo?> pdf(File file) async {
    PdfDocument? doc;
    try {
      doc = await PdfDocument.openFile(file.path);
      final pages = doc.pagesCount;
      if (pages < 1) return null;
      File? image;
      try {
        final page = await doc.getPage(1);
        try {
          final w = _maxPreviewWidth;
          final h = page.width > 0 ? w * page.height / page.width : w * 1.4;
          final img = await page.render(
            width: w,
            height: h,
            format: PdfPageImageFormat.jpeg,
            backgroundColor: '#FFFFFF',
            quality: 80,
          );
          if (img != null) {
            image = await (await _tmp('jpg')).writeAsBytes(img.bytes);
          }
        } finally {
          await page.close();
        }
      } catch (_) {
        image = null; // page count is still useful without the picture
      }
      return PdfInfo(pageCount: pages, image: image);
    } catch (_) {
      return null;
    } finally {
      try {
        await doc?.close();
      } catch (_) {}
    }
  }

  @override
  Future<File?> videoThumbnail(File file) async {
    try {
      final out = await _tmp('jpg');
      final path = await VideoThumbnail.thumbnailFile(
        video: file.path,
        thumbnailPath: out.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 640,
        quality: 75,
        timeMs: 0,
      );
      if (path == null) return null;
      final f = File(path);
      return await f.exists() && await f.length() > 0 ? f : null;
    } catch (_) {
      return null;
    }
  }
}
