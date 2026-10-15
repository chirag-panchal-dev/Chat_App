enum VoicePlaybackStatus { idle, loading, playing, paused, completed, error }

/// Audio playback abstraction (real impl uses `just_audio`).
abstract interface class VoicePlayer {
  Stream<VoicePlaybackStatus> get status;
  Stream<Duration> get position;

  /// Loads [url]; returns the audio length when known.
  Future<Duration?> load(String url);

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> stop();
  Future<void> dispose();
}
