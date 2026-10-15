import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/voice_models.dart';
import '../../domain/voice_recorder.dart';
import '../../domain/waveform.dart';
import 'voice_providers.dart';

enum RecorderPhase { idle, holding, locked }

class VoiceRecorderState {
  const VoiceRecorderState({
    this.phase = RecorderPhase.idle,
    this.elapsedMs = 0,
    this.levels = const [],
    this.cancelling = false,
    this.reachedLimit = false,
    this.error,
  });

  final RecorderPhase phase;
  final int elapsedMs;

  /// Live loudness samples (dBFS) for the recording animation.
  final List<double> levels;

  /// Finger slid far enough left: releasing cancels.
  final bool cancelling;
  final bool reachedLimit;
  final VoiceRecordError? error;

  bool get isRecording => phase != RecorderPhase.idle;

  VoiceRecorderState copyWith({
    RecorderPhase? phase,
    int? elapsedMs,
    List<double>? levels,
    bool? cancelling,
    bool? reachedLimit,
    Object? error = _keep,
  }) => VoiceRecorderState(
    phase: phase ?? this.phase,
    elapsedMs: elapsedMs ?? this.elapsedMs,
    levels: levels ?? this.levels,
    cancelling: cancelling ?? this.cancelling,
    reachedLimit: reachedLimit ?? this.reachedLimit,
    error: identical(error, _keep) ? this.error : error as VoiceRecordError?,
  );

  static const _keep = Object();
}

/// Records a voice note: hold-to-record (release sends, slide left cancels) or
/// tap-to-record (locked, with explicit cancel/send). Max 5 minutes, min 1 s.
class VoiceRecorderController extends Notifier<VoiceRecorderState> {
  VoiceRecorderController(this.conversationId);
  final String conversationId;

  /// Injectable clock for tests.
  static DateTime Function() now = DateTime.now;

  VoiceRecorder? _rec;
  StreamSubscription<double>? _ampSub;
  Timer? _ticker;
  DateTime? _startedAt;
  String? _path;
  final List<double> _samples = [];
  VoiceRecording? _stoppedAtLimit;

  @override
  VoiceRecorderState build() {
    ref.onDispose(() {
      _ticker?.cancel();
      _ampSub?.cancel();
      final r = _rec;
      if (r != null) {
        // Leaving the chat mid-recording discards it.
        r.cancel().then((_) => r.dispose());
      }
    });
    return const VoiceRecorderState();
  }

  int get _elapsedMs =>
      _startedAt == null ? 0 : now().difference(_startedAt!).inMilliseconds;

  /// Starts recording. Returns false when it could not start (permission
  /// denied, already recording, or a device error: see `state.error`).
  Future<bool> start({required bool locked}) async {
    if (state.isRecording) return false;
    state = state.copyWith(error: null);
    final rec = ref.read(voiceRecorderFactoryProvider)();
    try {
      if (!await rec.requestPermission()) {
        await rec.dispose();
        state = state.copyWith(error: VoiceRecordError.permissionDenied);
        return false;
      }
      final dir = await ref.read(voiceTempDirProvider)();
      _path = '$dir/voice_${const Uuid().v4()}.m4a';
      await rec.start(_path!);
    } catch (_) {
      await rec.dispose();
      state = state.copyWith(error: VoiceRecordError.failed);
      return false;
    }
    _rec = rec;
    _samples.clear();
    _stoppedAtLimit = null;
    _startedAt = now();
    _ampSub = rec.amplitude.listen((db) {
      _samples.add(db);
      final levels =
          _samples.length > 60
              ? _samples.sublist(_samples.length - 60)
              : List<double>.of(_samples);
      state = state.copyWith(levels: levels);
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final ms = _elapsedMs;
      state = state.copyWith(elapsedMs: ms);
      if (ms >= VoiceLimits.maxDuration.inMilliseconds) _hitLimit();
    });
    state = VoiceRecorderState(
      phase: locked ? RecorderPhase.locked : RecorderPhase.holding,
    );
    return true;
  }

  void lock() {
    if (state.phase == RecorderPhase.holding) {
      state = state.copyWith(phase: RecorderPhase.locked, cancelling: false);
    }
  }

  void setCancelling(bool value) {
    if (state.phase == RecorderPhase.holding && state.cancelling != value) {
      state = state.copyWith(cancelling: value);
    }
  }

  /// 5-minute cap: stop capturing and wait for the user to send or discard.
  Future<void> _hitLimit() async {
    _ticker?.cancel();
    await _ampSub?.cancel();
    final path = await _rec?.stop();
    if (path != null) {
      _stoppedAtLimit = VoiceRecording(
        file: File(path),
        durationMs: VoiceLimits.maxDuration.inMilliseconds,
        waveform: normalizeWaveform(_samples),
      );
    }
    state = state.copyWith(
      phase: RecorderPhase.locked,
      cancelling: false,
      reachedLimit: true,
      elapsedMs: VoiceLimits.maxDuration.inMilliseconds,
    );
  }

  /// Stops and returns the recording, or null if it was too short / failed
  /// (see `state.error`). The caller uploads and sends it.
  Future<VoiceRecording?> finish() async {
    if (!state.isRecording) return null;
    final ms = _elapsedMs;
    VoiceRecording? result = _stoppedAtLimit;
    if (result == null) {
      _ticker?.cancel();
      await _ampSub?.cancel();
      final path = await _rec?.stop();
      if (path != null) {
        result = VoiceRecording(
          file: File(path),
          durationMs: ms,
          waveform: normalizeWaveform(_samples),
        );
      }
    }
    final tooShort =
        result == null ||
        result.durationMs < VoiceLimits.minDuration.inMilliseconds;
    if (tooShort && result != null) {
      try {
        await result.file.delete();
      } catch (_) {}
    }
    await _teardown();
    if (result == null) {
      state = state.copyWith(error: VoiceRecordError.failed);
      return null;
    }
    if (tooShort) {
      state = state.copyWith(error: VoiceRecordError.tooShort);
      return null;
    }
    return result;
  }

  /// Discards the recording.
  Future<void> cancel() async {
    if (!state.isRecording) return;
    _ticker?.cancel();
    await _ampSub?.cancel();
    final stopped = _stoppedAtLimit;
    if (stopped != null) {
      try {
        await stopped.file.delete();
      } catch (_) {}
    } else {
      await _rec?.cancel();
    }
    await _teardown();
  }

  Future<void> _teardown() async {
    _ticker?.cancel();
    _ticker = null;
    await _ampSub?.cancel();
    _ampSub = null;
    final r = _rec;
    _rec = null;
    _startedAt = null;
    _stoppedAtLimit = null;
    _samples.clear();
    await r?.dispose();
    state = VoiceRecorderState(error: state.error);
  }

  void clearError() => state = state.copyWith(error: null);
}

final voiceRecorderProvider = NotifierProvider.autoDispose
    .family<VoiceRecorderController, VoiceRecorderState, String>(
      VoiceRecorderController.new,
    );
