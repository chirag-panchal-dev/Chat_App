import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/voice_player.dart';
import 'voice_providers.dart';

class VoicePlayerState {
  const VoicePlayerState({
    this.messageId,
    this.status = VoicePlaybackStatus.idle,
    this.position = Duration.zero,
    this.duration,
    this.speed = 1.0,
  });

  /// The voice note currently loaded (only one at a time).
  final String? messageId;
  final VoicePlaybackStatus status;
  final Duration position;
  final Duration? duration;
  final double speed;

  bool isActive(String id) => messageId == id;
  bool isPlaying(String id) =>
      messageId == id && status == VoicePlaybackStatus.playing;

  /// 0..1 progress for [id] (0 for other notes).
  double fraction(String id) {
    final d = duration;
    if (messageId != id || d == null || d.inMilliseconds == 0) return 0;
    return (position.inMilliseconds / d.inMilliseconds).clamp(0.0, 1.0);
  }

  VoicePlayerState copyWith({
    Object? messageId = _keep,
    VoicePlaybackStatus? status,
    Duration? position,
    Object? duration = _keep,
    double? speed,
  }) => VoicePlayerState(
    messageId:
        identical(messageId, _keep) ? this.messageId : messageId as String?,
    status: status ?? this.status,
    position: position ?? this.position,
    duration:
        identical(duration, _keep) ? this.duration : duration as Duration?,
    speed: speed ?? this.speed,
  );

  static const _keep = Object();
}

/// Plays one voice note at a time: tap to play/pause, scrub, 1x/1.5x/2x.
class VoicePlayerController extends Notifier<VoicePlayerState> {
  static const speeds = [1.0, 1.5, 2.0];
  StreamSubscription<VoicePlaybackStatus>? _statusSub;
  StreamSubscription<Duration>? _posSub;

  VoicePlayer get _player => ref.read(voicePlayerProvider);

  @override
  VoicePlayerState build() {
    final p = ref.read(voicePlayerProvider);
    _statusSub = p.status.listen((s) {
      if (state.messageId == null) return;
      // `completed` resets the position so a replay starts from the top.
      state = state.copyWith(
        status: s,
        position: s == VoicePlaybackStatus.completed ? Duration.zero : null,
      );
    });
    _posSub = p.position.listen((pos) {
      if (state.messageId != null &&
          state.status != VoicePlaybackStatus.completed) {
        state = state.copyWith(position: pos);
      }
    });
    ref.onDispose(() {
      _statusSub?.cancel();
      _posSub?.cancel();
    });
    return const VoicePlayerState();
  }

  /// Play/pause [messageId]; loads [url] first when it isn't the current note.
  Future<void> toggle(
    String messageId,
    String url, {
    Duration? knownDuration,
  }) async {
    if (state.messageId == messageId) {
      if (state.status == VoicePlaybackStatus.playing) {
        await _player.pause();
      } else if (state.status == VoicePlaybackStatus.error) {
        await _load(messageId, url, knownDuration);
      } else {
        if (state.status == VoicePlaybackStatus.completed) {
          await _player.seek(Duration.zero);
        }
        await _player.play();
      }
      return;
    }
    await _player.stop();
    await _load(messageId, url, knownDuration);
  }

  Future<void> _load(String messageId, String url, Duration? known) async {
    state = VoicePlayerState(
      messageId: messageId,
      status: VoicePlaybackStatus.loading,
      duration: known,
      speed: state.speed,
    );
    try {
      final d = await _player.load(url);
      await _player.setSpeed(state.speed);
      if (d != null) state = state.copyWith(duration: d);
      await _player.play();
    } catch (_) {
      state = state.copyWith(status: VoicePlaybackStatus.error);
    }
  }

  Future<void> seekFraction(String messageId, double f) async {
    if (state.messageId != messageId || state.duration == null) return;
    final target = Duration(
      milliseconds:
          (state.duration!.inMilliseconds * f.clamp(0.0, 1.0)).round(),
    );
    state = state.copyWith(position: target);
    await _player.seek(target);
  }

  Future<void> cycleSpeed() async {
    final next = speeds[(speeds.indexOf(state.speed) + 1) % speeds.length];
    state = state.copyWith(speed: next);
    if (state.messageId != null) await _player.setSpeed(next);
  }

  Future<void> stop() async {
    await _player.stop();
    state = const VoicePlayerState().copyWith(speed: state.speed);
  }
}

final voicePlayerControllerProvider =
    NotifierProvider<VoicePlayerController, VoicePlayerState>(
      VoicePlayerController.new,
    );
