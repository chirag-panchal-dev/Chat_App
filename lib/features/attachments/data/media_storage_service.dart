import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/errors/failure.dart';
import '../domain/media_uploader.dart';

/// Thin wrapper around Firebase Storage uploads with real progress.
class MediaStorageService implements MediaUploader {
  MediaStorageService(this._storage);
  final FirebaseStorage _storage;

  /// Handle that lets the UI cancel an in-flight upload.
  UploadTask? _current;

  @override
  void cancel() => _current?.cancel();

  /// Uploads [file] to [path]; [onProgress] receives 0..1.
  @override
  Future<void> upload(
    String path,
    File file, {
    required String contentType,
    void Function(double)? onProgress,
  }) async {
    final task = _storage
        .ref(path)
        .putFile(file, SettableMetadata(contentType: contentType));
    _current = task;
    final sub = task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) onProgress?.call(s.bytesTransferred / s.totalBytes);
    });
    try {
      await task;
    } catch (e) {
      throw Failure.from(e);
    } finally {
      await sub.cancel();
      _current = null;
    }
  }
}
