import 'dart:io';

import 'package:record/record.dart';

import '../domain/voice_recorder.dart';

/// Records 64 kbps mono AAC (m4a): ~0.5 MB per minute, plays on both
/// platforms. Nothing leaves the device until the user sends the note.
class RecordVoiceRecorder implements VoiceRecorder {
  RecordVoiceRecorder([AudioRecorder? recorder])
    : _rec = recorder ?? AudioRecorder();
  final AudioRecorder _rec;

  @override
  Future<bool> requestPermission() => _rec.hasPermission();

  @override
  Future<void> start(String path) => _rec.start(
    const RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 64000,
      sampleRate: 44100,
      numChannels: 1,
    ),
    path: path,
  );

  @override
  Stream<double> get amplitude => _rec
      .onAmplitudeChanged(const Duration(milliseconds: 100))
      .map((a) => a.current);

  @override
  Future<String?> stop() => _rec.stop();

  @override
  Future<void> cancel() async {
    final path = await _rec.stop();
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  @override
  Future<void> dispose() => _rec.dispose();
}
