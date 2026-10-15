/// Microphone recorder abstraction (real impl uses the `record` package).
abstract interface class VoiceRecorder {
  /// Asks for / checks the microphone permission. True when granted.
  Future<bool> requestPermission();

  /// Starts recording AAC audio into [path].
  Future<void> start(String path);

  /// Loudness in dBFS (~-60..0) while recording, ~10 times per second.
  Stream<double> get amplitude;

  /// Stops and returns the recorded file path (null if nothing was recorded).
  Future<String?> stop();

  /// Stops and deletes the partial file.
  Future<void> cancel();

  Future<void> dispose();
}
