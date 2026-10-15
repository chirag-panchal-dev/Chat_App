import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hushlo/core/errors/failure.dart';
import 'package:hushlo/core/firebase/media_url_provider.dart';
import 'package:hushlo/features/auth/presentation/viewmodels/auth_providers.dart';
import 'package:hushlo/features/chat/domain/entities/chat_message.dart';
import 'package:hushlo/features/chat/presentation/viewmodels/chat_view_model.dart';
import 'package:hushlo/features/chat/presentation/widgets/message_bubble.dart';
import 'package:hushlo/features/chat/presentation/widgets/pending_media_bubble.dart';
import 'package:hushlo/features/conversations/presentation/viewmodels/conversation_providers.dart';
import 'package:hushlo/features/attachments/data/image_processor.dart';
import 'package:hushlo/features/attachments/presentation/viewmodels/attachment_providers.dart';
import 'package:hushlo/features/files/data/file_opener.dart';
import 'package:hushlo/features/files/domain/file_rules.dart';
import 'package:hushlo/features/files/domain/picked_media.dart';
import 'package:hushlo/features/files/presentation/viewmodels/file_providers.dart';
import 'package:hushlo/features/files/presentation/widgets/pending_ring.dart';
import 'package:hushlo/features/voice/presentation/viewmodels/voice_providers.dart';

import '../helpers/pump_app.dart';
import 'fakes.dart';
import 'voice_test.dart' show FakeUploader;

class FakeProcessor extends ImageProcessor {
  FakeProcessor(this.dir);
  final Directory dir;
  @override
  Future<ProcessedImage> processForChat(File source, String messageId) async {
    final f = File('${dir.path}/$messageId.jpg')..writeAsBytesSync([1, 2, 3]);
    final t = File('${dir.path}/${messageId}_t.jpg')..writeAsBytesSync([1]);
    return ProcessedImage(
      file: f,
      thumbnail: t,
      width: 1200,
      height: 800,
      sizeBytes: 3,
    );
  }
}

class FakeOpener implements FileOpener {
  final calls = <String>[];
  Object? error;
  @override
  Future<void> open({
    required String url,
    required String messageId,
    required String fileName,
    required String mimeType,
  }) async {
    if (error != null) throw error!;
    calls.add('$url|$messageId|$fileName|$mimeType');
  }
}

void main() {
  group('file rules', () {
    test('document types are an allowlist', () {
      expect(documentMimeFor('Report.PDF'), 'application/pdf');
      expect(documentMimeFor('a.docx'), contains('wordprocessingml'));
      expect(documentMimeFor('data.csv'), 'text/csv');
      expect(documentMimeFor('virus.exe'), isNull);
      expect(documentMimeFor('page.html'), isNull);
      expect(documentMimeFor('script.js'), isNull);
      expect(documentMimeFor('noextension'), isNull);
      expect(documentMimeFor('archive.tar.gz'), isNull);
    });

    test('checkDocument: empty, type, size', () {
      expect(checkDocument('a.pdf', 1000), isNull);
      expect(checkDocument('a.pdf', 0), FileProblem.empty);
      expect(checkDocument('a.exe', 1000), FileProblem.unsupportedType);
      expect(checkDocument('a.pdf', FileLimits.maxDocumentBytes), isNull);
      expect(
        checkDocument('a.pdf', FileLimits.maxDocumentBytes + 1),
        FileProblem.tooLarge,
      );
    });

    test('checkVideo: size and duration', () {
      const ok = Duration(seconds: 30);
      expect(checkVideo(1000, ok), isNull);
      expect(checkVideo(0, ok), FileProblem.empty);
      expect(
        checkVideo(FileLimits.maxVideoBytes + 1, ok),
        FileProblem.tooLarge,
      );
      expect(
        checkVideo(1000, const Duration(minutes: 11)),
        FileProblem.videoTooLong,
      );
      expect(
        checkVideo(1000, const Duration(milliseconds: 100)),
        FileProblem.videoTooShort,
      );
      expect(
        checkVideo(FileLimits.maxVideoBytes, FileLimits.maxVideoDuration),
        isNull,
      );
    });

    test('video mime: iPhone .mov is QuickTime, the rest MP4', () {
      expect(videoMimeFor('clip.MOV'), 'video/quicktime');
      expect(videoMimeFor('clip.mp4'), 'video/mp4');
      expect(videoMimeFor('clip.m4v'), 'video/mp4');
    });

    test('sanitizeFileName strips paths and control chars, caps length', () {
      expect(sanitizeFileName('/etc/../passwd.pdf'), 'passwd.pdf');
      expect(sanitizeFileName(r'C:\docs\a.pdf'), 'a.pdf');
      expect(sanitizeFileName('  \u0000x\n.pdf '), 'x.pdf');
      expect(sanitizeFileName(''), 'file');
      final long = sanitizeFileName('${'a' * 300}.pdf');
      expect(long.length, FileLimits.maxFileNameLength);
      expect(long.endsWith('.pdf'), isTrue);
    });

    test('formatFileSize', () {
      expect(formatFileSize(850), '850 B');
      expect(formatFileSize(2048), '2.0 KB');
      expect(formatFileSize(300 * 1024), '300 KB');
      expect(formatFileSize(3 * 1024 * 1024 + 100 * 1024), '3.1 MB');
    });
  });

  group('sending documents and videos', () {
    late FakeChatRepository chat;
    late Directory dir;
    late List<String> uploaded;
    Object? uploadError;
    late ProviderContainer c;

    ChatViewModel vm() => c.read(chatViewModelProvider('a_b').notifier);
    ChatState st() => c.read(chatViewModelProvider('a_b'));
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 80));

    File tmp(String name, [int bytes = 1000]) =>
        File('${dir.path}/$name')..writeAsBytesSync(List.filled(bytes, 1));

    PickedDocument doc() => PickedDocument(
      file: tmp('report.pdf', 2048),
      fileName: 'report.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 2048,
    );
    PickedVideo video() => PickedVideo(
      file: tmp('clip.mp4', 4096),
      mimeType: 'video/mp4',
      sizeBytes: 4096,
      duration: const Duration(seconds: 12),
      width: 1080,
      height: 1920,
    );

    setUp(() {
      chat = FakeChatRepository();
      dir = Directory.systemTemp.createTempSync('files_test');
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
          imageProcessorProvider.overrideWithValue(FakeProcessor(dir)),
        ],
      );
      c.listen(chatViewModelProvider('a_b'), (_, __) {});
    });
    tearDown(() {
      c.dispose();
      dir.deleteSync(recursive: true);
    });

    test(
      'a photo is sent in the background and shown while uploading',
      () async {
        chat.imagesSent.clear();
        vm().sendPhoto(
          PickedPhoto(file: tmp('pic.jpg', 500), caption: 'Look!'),
        );
        expect(st().mediaUploads.single.isPhoto, isTrue);
        await settle();
        expect(chat.imagesSent.single['caption'], 'Look!');
        expect(chat.imagesSent.single['replyTo'], isNull);
        expect(st().mediaUploads, isEmpty);
      },
    );

    test('a failed photo stays for retry with the same id', () async {
      chat.mediaError = const PermissionFailure();
      vm().sendPhoto(PickedPhoto(file: tmp('pic.jpg', 500)));
      await settle();
      final u = st().mediaUploads.single;
      expect(u.failed, isTrue);
      chat.mediaError = null;
      vm().retryMedia(u.id);
      await settle();
      expect(chat.imagesSent.map((e) => e['id']), [u.id]);
    });

    test('the reply attaches to a photo', () async {
      vm().sendPhoto(PickedPhoto(file: tmp('pic.jpg', 500)), replyToId: 'orig');
      await settle();
      expect(chat.imagesSent.single['replyTo'], 'orig');
    });

    test(
      'a document uploads to the sender folder, then the message is written',
      () async {
        vm().sendDocument(doc());
        expect(st().mediaUploads, hasLength(1));
        await settle();
        expect(uploaded.single, startsWith('chatMedia/a_b/me/'));
        expect(uploaded.single, endsWith('.pdf|application/pdf'));
        final m = chat.fileSent.single;
        expect(m['name'], 'report.pdf');
        expect(m['size'], 2048);
        expect(m['mime'], 'application/pdf');
        expect(st().mediaUploads, isEmpty);
      },
    );

    test('a PDF preview and page count are uploaded and attached', () async {
      vm().sendDocument(
        PickedDocument(
          file: tmp('big.pdf', 2048),
          fileName: 'big.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 2048,
          preview: tmp('p.jpg', 300),
          pageCount: 12,
        ),
      );
      await settle();
      expect(uploaded, hasLength(2));
      expect(uploaded.first, endsWith('_thumb.jpg|image/jpeg'));
      expect(uploaded.last, endsWith('.pdf|application/pdf'));
      final m = chat.fileSent.single;
      expect(m['pages'], 12);
      expect(m['thumb'], contains('_thumb.jpg'));
      expect(m['thumb'], startsWith('chatMedia/a_b/me/'));
    });

    test('a video thumbnail is uploaded and attached', () async {
      vm().sendVideo(
        PickedVideo(
          file: tmp('v.mp4', 4096),
          mimeType: 'video/mp4',
          sizeBytes: 4096,
          duration: const Duration(seconds: 5),
          thumbnail: tmp('t.jpg', 300),
        ),
      );
      await settle();
      expect(uploaded.first, endsWith('_thumb.jpg|image/jpeg'));
      expect(chat.videoSent.single['thumb'], contains('_thumb.jpg'));
    });

    test('without a preview nothing extra is uploaded or sent', () async {
      vm().sendDocument(doc());
      await settle();
      expect(uploaded, hasLength(1));
      expect(chat.fileSent.single['thumb'], isNull);
      expect(chat.fileSent.single['pages'], isNull);
    });

    test('a video carries duration and dimensions', () async {
      vm().sendVideo(video());
      await settle();
      expect(uploaded.single, endsWith('.mp4|video/mp4'));
      final m = chat.videoSent.single;
      expect(m['durationMs'], 12000);
      expect(m['width'], 1080);
      expect(m['height'], 1920);
      expect(st().mediaUploads, isEmpty);
    });

    test(
      'a refused send keeps the upload for retry; retry reuses the id',
      () async {
        chat.mediaError = const PermissionFailure();
        vm().sendDocument(doc());
        await settle();
        expect(chat.fileSent, isEmpty);
        final u = st().mediaUploads.single;
        expect(u.failed, isTrue);
        chat.mediaError = null;
        vm().retryMedia(u.id);
        await settle();
        expect(chat.fileSent.map((e) => e['id']), [u.id]);
        expect(st().mediaUploads, isEmpty);
      },
    );

    test('discard removes a failed upload', () async {
      chat.mediaError = const PermissionFailure();
      vm().sendVideo(video());
      await settle();
      vm().discardMedia(st().mediaUploads.single.id);
      expect(st().mediaUploads, isEmpty);
    });

    test('the pending reply attaches to the upload and is cleared', () async {
      vm().setReplyTo(
        ChatMessage(
          id: 'orig',
          senderId: 'other',
          type: MessageType.text,
          createdAt: DateTime(2026),
          status: SendStatus.sent,
          text: 'hi',
        ),
      );
      vm().sendDocument(doc());
      expect(st().replyTo, isNull);
      await settle();
      expect(chat.fileSent.single['replyTo'], 'orig');
    });
  });

  group('pending media bubble', () {
    MediaUpload upload({
      bool video = false,
      double progress = 0.4,
      Failure? failure,
      int? pages = 12,
    }) =>
        video
            ? MediaUpload(
              id: 'u1',
              video: PickedVideo(
                file: File('/tmp/none.mp4'),
                mimeType: 'video/mp4',
                sizeBytes: 5 * 1024 * 1024,
                duration: const Duration(seconds: 75),
                width: 1080,
                height: 1920,
              ),
              progress: progress,
              failure: failure,
            )
            : MediaUpload(
              id: 'u1',
              doc: PickedDocument(
                file: File('/tmp/none.pdf'),
                fileName: 'Contract.pdf',
                mimeType: 'application/pdf',
                sizeBytes: 1536 * 1024,
                pageCount: pages,
              ),
              progress: progress,
              failure: failure,
            );

    Future<List<String>> pump(WidgetTester t, MediaUpload u) async {
      final calls = <String>[];
      await t.pumpApp(
        Scaffold(
          body: PendingMediaBubble(
            upload: u,
            onRetry: () => calls.add('retry'),
            onDiscard: () => calls.add('discard'),
          ),
        ),
      );
      await t.pump();
      return calls;
    }

    testWidgets(
      'uploading: the final card with pages, size and a cancel ring',
      (t) async {
        final calls = await pump(t, upload());
        expect(find.text('Contract.pdf'), findsOneWidget);
        expect(find.text('12 pages · 1.5 MB · PDF'), findsOneWidget);
        expect(find.text('Not sent'), findsNothing);
        await t.tap(find.byType(PendingRing));
        expect(calls, ['discard']);
      },
    );

    testWidgets('a video shows its length and size while uploading', (t) async {
      await pump(t, upload(video: true));
      expect(find.text('1:15 · 5.0 MB'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });

    testWidgets('failed: same card, Not sent, retry and remove', (t) async {
      final calls = await pump(t, upload(failure: const NetworkFailure()));
      expect(find.text('Contract.pdf'), findsOneWidget);
      expect(find.text('Not sent'), findsOneWidget);
      await t.tap(find.byType(PendingRing));
      await t.tap(find.text('Remove'));
      expect(calls, ['retry', 'discard']);
    });

    testWidgets('refused by the server: no retry, only remove', (t) async {
      final calls = await pump(t, upload(failure: const PermissionFailure()));
      expect(find.text('Retry'), findsNothing);
      await t.tap(find.byType(PendingRing));
      expect(calls, ['discard']);
    });
  });

  group('bubbles', () {
    ChatMessage fileMsg({String name = 'Quarterly report.pdf'}) => ChatMessage(
      id: 'f1',
      senderId: 'other',
      type: MessageType.file,
      createdAt: DateTime(2026, 1, 1, 9),
      status: SendStatus.sent,
      mediaPath: 'chatMedia/c/other/f1.pdf',
      fileName: name,
      mimeType: 'application/pdf',
      sizeBytes: 1536 * 1024,
    );
    ChatMessage videoMsg() => ChatMessage(
      id: 'v1',
      senderId: 'other',
      type: MessageType.video,
      createdAt: DateTime(2026, 1, 1, 9),
      status: SendStatus.sent,
      mediaPath: 'chatMedia/c/other/v1.mp4',
      durationMs: 75000,
      sizeBytes: 5 * 1024 * 1024,
      width: 1080,
      height: 1920,
    );

    Future<FakeOpener> pumpBubble(WidgetTester t, ChatMessage m) async {
      final opener = FakeOpener();
      await t.pumpApp(
        Scaffold(
          body: SingleChildScrollView(
            child: MessageBubble(
              conversationId: 'c',
              message: m,
              mine: false,
              myUid: 'me',
            ),
          ),
        ),
        overrides: [
          chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
          fileOpenerProvider.overrideWithValue(opener),
          mediaUrlProvider.overrideWith((ref, path) async => 'https://x/$path'),
        ],
      );
      await t.pump();
      return opener;
    }

    testWidgets('document card shows name, type and size; tap opens it', (
      t,
    ) async {
      final opener = await pumpBubble(t, fileMsg());
      expect(find.text('Quarterly report.pdf'), findsOneWidget);
      expect(find.text('1.5 MB · PDF'), findsOneWidget);
      await t.tap(find.text('Quarterly report.pdf'));
      await t.pump();
      await t.pump();
      expect(opener.calls, [
        'https://x/chatMedia/c/other/f1.pdf|f1|Quarterly report.pdf|application/pdf',
      ]);
    });

    testWidgets('PDF shows pages, size and extension under the name', (
      t,
    ) async {
      await pumpBubble(
        t,
        ChatMessage(
          id: 'p1',
          senderId: 'other',
          type: MessageType.file,
          createdAt: DateTime(2026, 1, 1, 9),
          status: SendStatus.sent,
          mediaPath: 'chatMedia/c/other/p1.pdf',
          thumbnailPath: 'chatMedia/c/other/p1_thumb.jpg',
          fileName: 'Report.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 1536 * 1024,
          pageCount: 12,
        ),
      );
      expect(find.text('Report.pdf'), findsOneWidget);
      expect(find.text('12 pages · 1.5 MB · PDF'), findsOneWidget);
    });

    testWidgets('a single page and no page count', (t) async {
      await pumpBubble(t, fileMsg(name: 'Notes.docx').copyWithPages(1));
      expect(find.textContaining('1 page · '), findsOneWidget);
    });

    testWidgets('a failed open tells the user', (t) async {
      final opener = await pumpBubble(t, fileMsg());
      opener.error = const NetworkFailure();
      await t.tap(find.text('Quarterly report.pdf'));
      await t.pump();
      await t.pump();
      expect(find.textContaining("Couldn't open this file"), findsOneWidget);
    });

    testWidgets('video card shows length and size', (t) async {
      await pumpBubble(t, videoMsg());
      expect(find.text('1:15 · 5.0 MB'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets(
      'a long caption wraps under the photo; the bubble stays as wide as the photo',
      (t) async {
        await pumpBubble(
          t,
          ChatMessage(
            id: 'i1',
            senderId: 'other',
            type: MessageType.image,
            createdAt: DateTime(2026, 1, 1, 9),
            status: SendStatus.sent,
            mediaPath: 'chatMedia/c/other/i1.jpg',
            thumbnailPath: 'chatMedia/c/other/i1_t.jpg',
            width: 1200,
            height: 800,
            text: List.filled(60, 'caption').join(' '),
          ),
        );
        final w = t.getSize(find.byType(IntrinsicWidth).first).width;
        expect(w, lessThanOrEqualTo(260.5));
        expect(w, greaterThan(250));
      },
    );

    testWidgets('video and PDF-preview bubbles are the same width', (t) async {
      await pumpBubble(t, videoMsg());
      expect(
        t.getSize(find.byType(IntrinsicWidth).first).width,
        lessThanOrEqualTo(260.5),
      );
    });

    test('reply previews and labels', () {
      expect(fileMsg().previewText('Photo'), 'Quarterly report.pdf');
      expect(videoMsg().previewText('Photo', videoLabel: 'Video'), 'Video');
    });
  });
}

extension on ChatMessage {
  ChatMessage copyWithPages(int pages) => ChatMessage(
    id: id,
    senderId: senderId,
    type: type,
    createdAt: createdAt,
    status: status,
    mediaPath: mediaPath,
    fileName: fileName,
    mimeType: mimeType,
    sizeBytes: sizeBytes,
    pageCount: pages,
  );
}
