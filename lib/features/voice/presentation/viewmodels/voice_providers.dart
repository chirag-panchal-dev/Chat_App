import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../attachments/data/media_storage_service.dart';
import '../../../attachments/domain/media_uploader.dart';
import '../../data/just_audio_voice_player.dart';
import '../../data/record_voice_recorder.dart';
import '../../domain/voice_player.dart';
import '../../domain/voice_recorder.dart';

/// Creates a recorder per recording session (overridable in tests).
final voiceRecorderFactoryProvider = Provider<VoiceRecorder Function()>(
  (_) => () => RecordVoiceRecorder(),
);

/// Folder for in-progress recordings.
final voiceTempDirProvider = Provider<Future<String> Function()>(
  (_) => () async => (await getTemporaryDirectory()).path,
);

/// One shared player: only one voice note plays at a time.
final voicePlayerProvider = Provider<VoicePlayer>((ref) {
  final p = JustAudioVoicePlayer();
  ref.onDispose(p.dispose);
  return p;
});

/// A fresh uploader per voice note so each upload can be cancelled on its own.
final mediaUploaderFactoryProvider = Provider<MediaUploader Function()>(
  (ref) => () => MediaStorageService(ref.read(firebaseStorageProvider)),
);
