import 'package:just_audio/just_audio.dart';

import '../domain/voice_player.dart';

class JustAudioVoicePlayer implements VoicePlayer {
  JustAudioVoicePlayer([AudioPlayer? player]) : _p = player ?? AudioPlayer();
  final AudioPlayer _p;

  @override
  Stream<VoicePlaybackStatus> get status => _p.playerStateStream.map((s) {
    switch (s.processingState) {
      case ProcessingState.idle:
        return VoicePlaybackStatus.idle;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        return s.playing
            ? VoicePlaybackStatus.loading
            : VoicePlaybackStatus.loading;
      case ProcessingState.ready:
        return s.playing
            ? VoicePlaybackStatus.playing
            : VoicePlaybackStatus.paused;
      case ProcessingState.completed:
        return VoicePlaybackStatus.completed;
    }
  });

  @override
  Stream<Duration> get position => _p.positionStream;

  @override
  Future<Duration?> load(String url) => _p.setUrl(url);

  @override
  Future<void> play() => _p.play();

  @override
  Future<void> pause() => _p.pause();

  @override
  Future<void> seek(Duration position) => _p.seek(position);

  @override
  Future<void> setSpeed(double speed) => _p.setSpeed(speed);

  @override
  Future<void> stop() => _p.stop();

  @override
  Future<void> dispose() => _p.dispose();
}
