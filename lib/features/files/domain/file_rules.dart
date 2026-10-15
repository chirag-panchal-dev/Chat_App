import 'dart:math';

/// Product limits for documents and videos (mirrored in the security rules).
abstract final class FileLimits {
  static const maxDocumentBytes = 25 * 1024 * 1024;
  static const maxVideoBytes = 50 * 1024 * 1024;
  static const maxVideoDuration = Duration(minutes: 10);
  static const minVideoDuration = Duration(milliseconds: 300);
  static const maxFileNameLength = 200;
}

/// File extensions the app sends as documents, with the MIME type used for
/// the upload. Anything else is refused (no executables, scripts, HTML).
const documentMimeByExtension = <String, String>{
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'txt': 'text/plain',
  'csv': 'text/csv',
  'zip': 'application/zip',
};

List<String> get documentExtensions => documentMimeByExtension.keys.toList();

/// Lower-case extension without the dot ('' when there is none).
String fileExtension(String name) {
  final i = name.lastIndexOf('.');
  return i < 0 || i == name.length - 1
      ? ''
      : name.substring(i + 1).toLowerCase();
}

/// MIME type for a document name, or null when the type isn't allowed.
String? documentMimeFor(String fileName) =>
    documentMimeByExtension[fileExtension(fileName)];

/// MIME type for a picked video (iPhone recordings are QuickTime).
String videoMimeFor(String fileName) =>
    fileExtension(fileName) == 'mov' ? 'video/quicktime' : 'video/mp4';

/// Display name safe to store: no path separators or control characters,
/// trimmed, capped at 200 characters (keeping the extension).
String sanitizeFileName(String raw) {
  var n =
      raw
          .split(RegExp(r'[\\/]'))
          .last
          .replaceAll(RegExp(r'[\x00-\x1f]'), '')
          .trim();
  if (n.isEmpty) return 'file';
  if (n.length > FileLimits.maxFileNameLength) {
    final ext = fileExtension(n);
    final keep =
        FileLimits.maxFileNameLength - (ext.isEmpty ? 0 : ext.length + 1);
    final base = n.substring(0, max(1, keep));
    n = ext.isEmpty ? base : '$base.$ext';
  }
  return n;
}

enum FileProblem {
  unsupportedType,
  tooLarge,
  empty,
  videoTooLong,
  videoTooShort,
}

/// Null when [fileName] / [sizeBytes] is OK to send as a document.
FileProblem? checkDocument(String fileName, int sizeBytes) {
  if (sizeBytes <= 0) return FileProblem.empty;
  if (documentMimeFor(fileName) == null) return FileProblem.unsupportedType;
  if (sizeBytes > FileLimits.maxDocumentBytes) return FileProblem.tooLarge;
  return null;
}

/// Null when the video is OK to send.
FileProblem? checkVideo(int sizeBytes, Duration duration) {
  if (sizeBytes <= 0) return FileProblem.empty;
  if (sizeBytes > FileLimits.maxVideoBytes) return FileProblem.tooLarge;
  if (duration > FileLimits.maxVideoDuration) return FileProblem.videoTooLong;
  if (duration < FileLimits.minVideoDuration) return FileProblem.videoTooShort;
  return null;
}

/// "850 B", "12.4 KB", "3.1 MB".
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(bytes < 10 * 1024 ? 1 : 0)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
