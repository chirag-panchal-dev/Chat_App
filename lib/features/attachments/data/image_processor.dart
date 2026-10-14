import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/failure.dart';

class ProcessedImage {
  const ProcessedImage({
    required this.file,
    required this.thumbnail,
    required this.width,
    required this.height,
    required this.sizeBytes,
  });

  final File file;
  final File thumbnail;
  final int width;
  final int height;
  final int sizeBytes;
  String get mimeType => 'image/jpeg';
}

/// Validates picked images and produces upload-ready JPEGs (rescaled, EXIF
/// orientation applied) plus a small thumbnail for list display.
class ImageProcessor {
  static const _allowed = {'.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif'};
  static const _maxEdge = 1600;
  static const _thumbEdge = 400;

  /// Throws a [ValidationFailure] for unsupported or oversized input.
  Future<void> validate(File source) async {
    final ext = p.extension(source.path).toLowerCase();
    if (!_allowed.contains(ext)) {
      throw const ValidationFailure(ValidationReason.fileUnsupported);
    }
    final size = await source.length();
    if (size > AppConfig.maxPickedImageBytes) {
      throw const ValidationFailure(ValidationReason.fileTooLarge);
    }
  }

  Future<File> _compress(File src, String name, int edge, int quality) async {
    final dir = await getTemporaryDirectory();
    final target = p.join(dir.path, name);
    final out = await FlutterImageCompress.compressAndGetFile(
      src.path,
      target,
      minWidth: edge,
      minHeight: edge,
      quality: quality,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    if (out == null) {
      throw const ValidationFailure(ValidationReason.fileUnsupported);
    }
    return File(out.path);
  }

  Future<ProcessedImage> processForChat(File source, String id) async {
    await validate(source);
    final main = await _compress(source, '$id.jpg', _maxEdge, 80);
    final thumb = await _compress(source, '${id}_thumb.jpg', _thumbEdge, 70);
    final size = await main.length();
    if (size > AppConfig.maxPickedImageBytes) {
      throw const ValidationFailure(ValidationReason.fileTooLarge);
    }
    final dims = await _dimensions(main);
    return ProcessedImage(
      file: main,
      thumbnail: thumb,
      width: dims.$1,
      height: dims.$2,
      sizeBytes: size,
    );
  }

  Future<File> processAvatar(File source) async {
    await validate(source);
    return _compress(
      source,
      'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
      512,
      80,
    );
  }

  Future<(int, int)> _dimensions(File f) async {
    final codec = await ui.instantiateImageCodec(await f.readAsBytes());
    final frame = await codec.getNextFrame();
    final r = (frame.image.width, frame.image.height);
    frame.image.dispose();
    codec.dispose();
    return r;
  }
}

/// Chat-bubble aspect ratio helper kept next to the dimensions it derives from.
double clampedAspect(int? w, int? h) {
  if (w == null || h == null || w <= 0 || h <= 0) return 4 / 3;
  return (w / h).clamp(0.6, 1.8).toDouble();
}
