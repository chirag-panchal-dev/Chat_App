import 'file_rules.dart';
import 'picked_media.dart';

/// Thrown when the chosen file can't be sent; [problem] says why.
class FilePickException implements Exception {
  const FilePickException(this.problem);
  final FileProblem problem;
  @override
  String toString() => 'FilePickException($problem)';
}

enum VideoSource { gallery, camera }

/// Chooses a document or video and validates it against the product limits.
/// Returns null when the user cancels; throws [FilePickException] when the
/// file is not allowed.
abstract interface class MediaPicker {
  Future<PickedDocument?> pickDocument();
  Future<PickedVideo?> pickVideo(VideoSource source);
}
