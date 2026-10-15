import 'dart:io';

/// What could be read from a PDF: its page count and, when rendering worked,
/// a JPEG of the first page.
class PdfInfo {
  const PdfInfo({required this.pageCount, this.image});
  final int pageCount;
  final File? image;
}

/// Makes the small preview images shown in chat bubbles (done on the sender's
/// phone before upload, so receivers never need to render anything).
abstract interface class MediaPreviews {
  /// Null when the PDF can't be read (damaged, password-protected, …): the
  /// document is then sent without a preview.
  Future<PdfInfo?> pdf(File file);

  /// A JPEG frame from the start of the video, or null if none could be made.
  Future<File?> videoThumbnail(File file);
}
