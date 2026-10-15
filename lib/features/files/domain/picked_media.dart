import 'dart:io';

/// A document chosen by the user, ready to upload.
class PickedDocument {
  const PickedDocument({
    required this.file,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    this.preview,
    this.pageCount,
  });
  final File file;
  final String fileName;
  final String mimeType;
  final int sizeBytes;

  /// PDFs: JPEG of the first page and the page count (when readable).
  final File? preview;
  final int? pageCount;
}

/// A video chosen by the user, with metadata read from the file.
class PickedVideo {
  const PickedVideo({
    required this.file,
    required this.mimeType,
    required this.sizeBytes,
    required this.duration,
    this.width,
    this.height,
    this.thumbnail,
  });
  final File file;
  final String mimeType;

  /// JPEG frame shown in the bubble before the video is opened.
  final File? thumbnail;
  final int sizeBytes;
  final Duration duration;
  final int? width;
  final int? height;
}

/// A photo chosen in the preview screen, with its optional caption. It is
/// compressed and uploaded in the background (see `MediaUpload`).
class PickedPhoto {
  const PickedPhoto({required this.file, this.caption});
  final File file;
  final String? caption;
}
