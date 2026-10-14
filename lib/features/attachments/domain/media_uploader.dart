import 'dart:io';

abstract interface class MediaUploader {
  Future<void> upload(
    String path,
    File file, {
    required String contentType,
    void Function(double progress)? onProgress,
  });

  void cancel();
}
