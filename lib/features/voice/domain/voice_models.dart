import 'dart:io';

/// Product limits for voice notes (mirrored in the security rules).
abstract final class VoiceLimits {
  static const maxDuration = Duration(minutes: 5);
  static const minDuration = Duration(seconds: 1);
  static const waveformBars = 48;
  static const mimeType = 'audio/mp4';
}

/// A finished recording ready to upload.
class VoiceRecording {
  const VoiceRecording({
    required this.file,
    required this.durationMs,
    required this.waveform,
  });

  final File file;
  final int durationMs;

  /// Bar heights 0..100 used to draw the bubble without downloading audio.
  final List<int> waveform;
}

enum VoiceRecordError { permissionDenied, tooShort, failed }

/// "m:ss" for a duration in milliseconds (0:07, 1:05, 12:00).
String formatVoiceDuration(int ms) {
  final totalSeconds = (ms / 1000).round();
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
