import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:hushlo/features/chat/presentation/widgets/composer.dart';
import '../helpers/pump_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hushlo/core/errors/failure.dart';
import 'package:hushlo/features/attachments/domain/media_uploader.dart';
import 'package:hushlo/features/auth/presentation/viewmodels/auth_providers.dart';
import 'package:hushlo/features/chat/presentation/viewmodels/chat_view_model.dart';
import 'package:hushlo/features/conversations/presentation/viewmodels/conversation_providers.dart';
import 'package:hushlo/features/voice/domain/voice_models.dart';
import 'package:hushlo/features/voice/domain/voice_player.dart';
import 'package:hushlo/features/voice/domain/voice_recorder.dart';
import 'package:hushlo/features/voice/domain/waveform.dart';
import 'package:hushlo/features/voice/presentation/viewmodels/voice_player_controller.dart';
import 'package:hushlo/features/voice/presentation/viewmodels/voice_providers.dart';
import 'package:hushlo/features/voice/presentation/viewmodels/voice_recorder_controller.dart';

import 'fakes.dart';

class FakeRecorder implements VoiceRecorder {
  FakeRecorder(this.dir, {this.granted = true});
  final String dir;
  final bool granted;
  final amp = StreamController<double>.broadcast();
  bool cancelled = false;
  String? path;

  @override
  Future<bool> requestPermission() async => granted;
  @override
  Future<void> start(String p) async => path = p;
  @override
  Stream<double> get amplitude => amp.stream;
  @override
  Future<String?> stop() async {
    File(path!).writeAsBytesSync([1, 2, 3]);
    return path;
  }

  @override
  Future<void> cancel() async => cancelled = true;
  @override
  Future<void> dispose() async {}
}

class FakePlayer implements VoicePlayer {
  final st = StreamController<VoicePlaybackStatus>.broadcast();
  final pos = StreamController<Duration>.broadcast();
  final calls = <String>[];
  Object? loadError;

  @override
  Stream<VoicePlaybackStatus> get status => st.stream;
  @override
  Stream<Duration> get position => pos.stream;
  @override
  Future<Duration?> load(String url) async {
    calls.add('load:$url');
    if (loadError != null) throw loadError!;
    return const Duration(seconds: 10);
  }

  @override
  Future<void> play() async {
    calls.add('play');
    st.add(VoicePlaybackStatus.playing);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    st.add(VoicePlaybackStatus.paused);
  }

  @override
  Future<void> seek(Duration p) async => calls.add('seek:${p.inSeconds}');
  @override
  Future<void> setSpeed(double s) async => calls.add('speed:$s');
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> dispose() async {}
}

class FakeUploader implements MediaUploader {
  FakeUploader(this.log, {this.error});
  final List<String> log;
  final Object? error;
  @override
  Future<void> upload(
    String path,
    File file, {
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.5);
    if (error != null) throw error!;
    log.add('$path|$contentType');
  }

  @override
  void cancel() {}
}

void main() {
  composerTests();
  group('waveform', () {
    test('always returns the requested number of bars within 0..100', () {
      final w = normalizeWaveform(List.generate(500, (i) => -60.0 + i % 61));
      expect(w, hasLength(VoiceLimits.waveformBars));
      expect(w.every((b) => b >= 8 && b <= 100), isTrue);
    });
    test('no samples gives a flat low waveform', () {
      expect(normalizeWaveform(const []), everyElement(8));
    });
    test('a short peak survives bucketing', () {
      final s = List<double>.filled(480, -60)..[100] = 0;
      expect(normalizeWaveform(s).contains(100), isTrue);
    });
    test('formats durations', () {
      expect(formatVoiceDuration(7000), '0:07');
      expect(formatVoiceDuration(65000), '1:05');
    });
  });

  group('recorder controller', () {
    late Directory dir;
    late FakeRecorder rec;
    late ProviderContainer c;
    var clock = DateTime(2026);

    VoiceRecorderController ctl() =>
        c.read(voiceRecorderProvider('a_b').notifier);
    VoiceRecorderState st() => c.read(voiceRecorderProvider('a_b'));

    setUp(() {
      dir = Directory.systemTemp.createTempSync('voice_test');
      clock = DateTime(2026);
      VoiceRecorderController.now = () => clock;
    });
    tearDown(() {
      VoiceRecorderController.now = DateTime.now;
      c.dispose();
      dir.deleteSync(recursive: true);
    });

    void make({bool granted = true}) {
      rec = FakeRecorder(dir.path, granted: granted);
      c = ProviderContainer(
        overrides: [
          voiceRecorderFactoryProvider.overrideWithValue(() => rec),
          voiceTempDirProvider.overrideWithValue(() async => dir.path),
        ],
      );
      c.listen(voiceRecorderProvider('a_b'), (_, __) {});
    }

    test('permission denied reports an error and does not record', () async {
      make(granted: false);
      expect(await ctl().start(locked: false), isFalse);
      expect(st().error, VoiceRecordError.permissionDenied);
      expect(st().isRecording, isFalse);
    });

    test('too short recording is discarded with an error', () async {
      make();
      await ctl().start(locked: false);
      clock = clock.add(const Duration(milliseconds: 400));
      expect(await ctl().finish(), isNull);
      expect(st().error, VoiceRecordError.tooShort);
      expect(st().isRecording, isFalse);
    });

    test('a valid recording is returned with duration and waveform', () async {
      make();
      await ctl().start(locked: true);
      expect(st().phase, RecorderPhase.locked);
      rec.amp.add(-20);
      await Future<void>.delayed(Duration.zero);
      clock = clock.add(const Duration(seconds: 3));
      final r = await ctl().finish();
      expect(r, isNotNull);
      expect(r!.durationMs, 3000);
      expect(r.waveform, hasLength(VoiceLimits.waveformBars));
      expect(st().isRecording, isFalse);
    });

    test(
      'hold can be locked, cancelling flag only applies while holding',
      () async {
        make();
        await ctl().start(locked: false);
        ctl().setCancelling(true);
        expect(st().cancelling, isTrue);
        ctl().lock();
        expect(st().phase, RecorderPhase.locked);
        expect(st().cancelling, isFalse);
        ctl().setCancelling(true);
        expect(st().cancelling, isFalse);
      },
    );

    test('cancel stops without producing a recording', () async {
      make();
      await ctl().start(locked: false);
      await ctl().cancel();
      expect(rec.cancelled, isTrue);
      expect(st().isRecording, isFalse);
    });
  });

  group('player controller', () {
    late FakePlayer player;
    late ProviderContainer c;
    setUp(() {
      player = FakePlayer();
      c = ProviderContainer(
        overrides: [voicePlayerProvider.overrideWithValue(player)],
      );
      c.listen(voicePlayerControllerProvider, (_, __) {});
    });
    tearDown(() => c.dispose());

    VoicePlayerController ctl() =>
        c.read(voicePlayerControllerProvider.notifier);
    VoicePlayerState st() => c.read(voicePlayerControllerProvider);
    Future<void> tick() => Future<void>.delayed(Duration.zero);

    test('plays, pauses, and resumes the same note', () async {
      await ctl().toggle('m1', 'u1');
      await tick();
      expect(st().isPlaying('m1'), isTrue);
      await ctl().toggle('m1', 'u1');
      await tick();
      expect(st().isPlaying('m1'), isFalse);
      await ctl().toggle('m1', 'u1');
      expect(player.calls.where((e) => e.startsWith('load')), hasLength(1));
    });

    test('starting another note stops the first (one at a time)', () async {
      await ctl().toggle('m1', 'u1');
      await ctl().toggle('m2', 'u2');
      await tick();
      expect(st().messageId, 'm2');
      expect(player.calls, contains('stop'));
    });

    test('progress fraction follows position', () async {
      await ctl().toggle('m1', 'u1');
      player.pos.add(const Duration(seconds: 5));
      await tick();
      expect(st().fraction('m1'), closeTo(0.5, 0.01));
      expect(st().fraction('other'), 0);
    });

    test('speed cycles 1x -> 1.5x -> 2x -> 1x', () async {
      await ctl().cycleSpeed();
      expect(st().speed, 1.5);
      await ctl().cycleSpeed();
      expect(st().speed, 2.0);
      await ctl().cycleSpeed();
      expect(st().speed, 1.0);
    });

    test('load failure sets error and a tap retries', () async {
      player.loadError = Exception('x');
      await ctl().toggle('m1', 'u1');
      expect(st().status, VoicePlaybackStatus.error);
      player.loadError = null;
      await ctl().toggle('m1', 'u1');
      await tick();
      expect(st().isPlaying('m1'), isTrue);
    });
  });

  group('sending voice notes', () {
    late FakeChatRepository chat;
    late Directory dir;
    late List<String> uploaded;
    Object? uploadError;
    late ProviderContainer c;

    ChatViewModel vm() => c.read(chatViewModelProvider('a_b').notifier);
    ChatState state() => c.read(chatViewModelProvider('a_b'));
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 80));

    VoiceRecording recording() {
      final f = File(
        '${dir.path}/r${DateTime.now().microsecondsSinceEpoch}.m4a',
      )..writeAsBytesSync(List.filled(2000, 1));
      return VoiceRecording(
        file: f,
        durationMs: 4200,
        waveform: List.filled(VoiceLimits.waveformBars, 40),
      );
    }

    setUp(() {
      chat = FakeChatRepository();
      dir = Directory.systemTemp.createTempSync('voice_send');
      uploaded = [];
      uploadError = null;
      c = ProviderContainer(
        overrides: [
          currentUidProvider.overrideWithValue('me'),
          chatRepositoryProvider.overrideWithValue(chat),
          conversationRepositoryProvider.overrideWithValue(
            FakeConversationRepository(),
          ),
          mediaUploaderFactoryProvider.overrideWithValue(
            () => FakeUploader(uploaded, error: uploadError),
          ),
        ],
      );
      c.listen(chatViewModelProvider('a_b'), (_, __) {});
    });
    tearDown(() {
      c.dispose();
      dir.deleteSync(recursive: true);
    });

    test(
      'uploads then writes the message once, then clears progress',
      () async {
        vm().sendVoice(recording());
        expect(state().voiceUploads, hasLength(1));
        await settle();
        expect(uploaded, hasLength(1));
        expect(uploaded.single, startsWith('chatMedia/a_b/me/'));
        expect(uploaded.single, endsWith('.m4a|audio/mp4'));
        expect(chat.voiceSent, hasLength(1));
        expect(chat.voiceSent.single['durationMs'], 4200);
        expect(chat.voiceSent.single['size'], 2000);
        expect(state().voiceUploads, isEmpty);
      },
    );

    test('a refused send keeps the note and sends nothing', () async {
      chat.voiceError = const PermissionFailure();
      vm().sendVoice(recording());
      await settle();
      expect(chat.voiceSent, isEmpty);
      expect(state().voiceUploads.single.failed, isTrue);
    });

    test('retry reuses the same id so there are no duplicates', () async {
      chat.voiceError = const PermissionFailure();
      vm().sendVoice(recording());
      await settle();
      final id = state().voiceUploads.single.id;
      chat.voiceError = null;
      vm().retryVoice(id);
      await settle();
      expect(chat.voiceSent.map((e) => e['id']), [id]);
      expect(state().voiceUploads, isEmpty);
    });

    test('discard removes a failed note', () async {
      chat.voiceError = const PermissionFailure();
      vm().sendVoice(recording());
      await settle();
      vm().discardVoice(state().voiceUploads.single.id);
      expect(state().voiceUploads, isEmpty);
    });
  });
}

void composerTests() {
  group('Composer voice', () {
    late Directory dir;
    late FakeRecorder rec;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('voice_ui');
      rec = FakeRecorder(dir.path);
    });
    tearDown(() => dir.deleteSync(recursive: true));

    List<Override> overrides() => [
      voiceRecorderFactoryProvider.overrideWithValue(() => rec),
      voiceTempDirProvider.overrideWithValue(() async => dir.path),
    ];

    testWidgets('mic shows when empty, send shows once there is text', (
      t,
    ) async {
      await t.pumpApp(
        Scaffold(
          body: Composer(
            onSend: (_) => true,
            onAttach: () {},
            conversationId: 'a_b',
            onVoice: (_) {},
          ),
        ),
        overrides: overrides(),
      );
      expect(find.bySemanticsLabel('Record voice message'), findsOneWidget);
      expect(find.byTooltip('Send'), findsNothing);
      await t.enterText(find.byType(TextField), 'hi');
      await t.pump();
      expect(find.byTooltip('Send'), findsOneWidget);
      expect(find.bySemanticsLabel('Record voice message'), findsNothing);
    });

    testWidgets('tap records locked; send hands the recording over', (t) async {
      VoiceRecording? got;
      await t.pumpApp(
        Scaffold(
          body: Composer(
            onSend: (_) => true,
            onAttach: () {},
            conversationId: 'a_b',
            onVoice: (r) => got = r,
          ),
        ),
        overrides: overrides(),
      );
      await t.runAsync(() async {
        await t.tap(find.bySemanticsLabel('Record voice message'));
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      });
      await t.pump();
      expect(find.byTooltip('Send voice message'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await t.runAsync(() async {
        await t.tap(find.byTooltip('Send voice message'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await t.pump();
      expect(got, isNotNull);
      expect(got!.durationMs, greaterThanOrEqualTo(1000));
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('without onVoice there is no mic (text-only)', (t) async {
      await t.pumpApp(
        Scaffold(body: Composer(onSend: (_) => true, onAttach: () {})),
      );
      expect(find.bySemanticsLabel('Record voice message'), findsNothing);
    });
  });
}
