import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../domain/file_rules.dart';
import '../domain/media_picker.dart';
import '../domain/media_previews.dart';
import '../domain/picked_media.dart';

/// file_picker for documents (system document picker, no storage permission),
/// image_picker for videos, video_player to read duration and size.
class PluginMediaPicker implements MediaPicker {
  PluginMediaPicker(this._images, this._previews);
  final ImagePicker _images;
  final MediaPreviews _previews;

  @override
  Future<PickedDocument?> pickDocument() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: documentExtensions,
      allowMultiple: false,
    );
    final f = res?.files.single;
    final path = f?.path;
    if (f == null || path == null) return null;
    final name = sanitizeFileName(f.name);
    final file = File(path);
    final size = f.size > 0 ? f.size : await file.length();
    final problem = checkDocument(name, size);
    if (problem != null) throw FilePickException(problem);
    final mime = documentMimeFor(name)!;
    final pdf = mime == 'application/pdf' ? await _previews.pdf(file) : null;
    return PickedDocument(
      file: file,
      fileName: name,
      mimeType: mime,
      sizeBytes: size,
      preview: pdf?.image,
      pageCount: pdf?.pageCount,
    );
  }

  @override
  Future<PickedVideo?> pickVideo(VideoSource source) async {
    final x = await _images.pickVideo(
      source:
          source == VideoSource.camera
              ? ImageSource.camera
              : ImageSource.gallery,
      maxDuration: FileLimits.maxVideoDuration,
    );
    if (x == null) return null;
    final file = File(x.path);
    final size = await file.length();
    final c = VideoPlayerController.file(file);
    try {
      await c.initialize();
      final duration = c.value.duration;
      final problem = checkVideo(size, duration);
      if (problem != null) throw FilePickException(problem);
      final s = c.value.size;
      final thumb = await _previews.videoThumbnail(file);
      return PickedVideo(
        file: file,
        mimeType: videoMimeFor(x.name.isEmpty ? x.path : x.name),
        sizeBytes: size,
        duration: duration,
        width: s.width > 0 ? s.width.round() : null,
        height: s.height > 0 ? s.height.round() : null,
        thumbnail: thumb,
      );
    } finally {
      await c.dispose();
    }
  }
}
