import 'dart:io';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/presentation/viewmodels/auth_providers.dart';
import '../../../conversations/domain/entities/conversation.dart';
import '../../../conversations/presentation/viewmodels/conversation_providers.dart';
import '../../../attachments/domain/media_uploader.dart';
import '../../../attachments/domain/send_image_message_use_case.dart';
import '../../../attachments/presentation/viewmodels/attachment_providers.dart';
import '../../../files/domain/picked_media.dart';
import '../../../files/domain/send_media_message_use_case.dart';
import '../../../voice/domain/send_voice_message_use_case.dart';
import '../../../voice/domain/voice_models.dart';
import '../../../voice/presentation/viewmodels/voice_providers.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../privacy_settings/presentation/viewmodels/settings_providers.dart';
import 'chat_providers.dart';

export 'chat_providers.dart';

/// WhatsApp-style reaction toggle: tapping the emoji you already used removes
/// it; any other emoji replaces/sets your reaction. Returns null to remove.
String? nextReaction(String? current, String tapped) =>
    current == tapped ? null : tapped;

/// A voice note being uploaded (or that failed to upload) in this chat.
class VoiceUpload {
  const VoiceUpload({
    required this.id,
    required this.recording,
    this.replyToId,
    this.progress = 0,
    this.failure,
  });

  final String id;
  final VoiceRecording recording;
  final String? replyToId;
  final double progress;
  final Failure? failure;

  bool get failed => failure != null;

  VoiceUpload copyWith({double? progress, Object? failure = _keep}) =>
      VoiceUpload(
        id: id,
        recording: recording,
        replyToId: replyToId,
        progress: progress ?? this.progress,
        failure: identical(failure, _keep) ? this.failure : failure as Failure?,
      );

  static const _keep = Object();
}

/// A document or video being uploaded (progress, cancel) or that failed
/// (retry / remove). Same id on retry => no duplicate message.
class MediaUpload {
  const MediaUpload({
    required this.id,
    this.doc,
    this.video,
    this.photo,
    this.replyToId,
    this.progress = 0,
    this.failure,
  }) : assert(
         (doc != null ? 1 : 0) +
                 (video != null ? 1 : 0) +
                 (photo != null ? 1 : 0) ==
             1,
       );

  final String id;
  final PickedDocument? doc;
  final PickedVideo? video;
  final PickedPhoto? photo;
  final String? replyToId;
  final double progress;
  final Failure? failure;

  bool get isVideo => video != null;
  bool get isPhoto => photo != null;
  bool get failed => failure != null;
  File get file => doc?.file ?? video?.file ?? photo!.file;

  MediaUpload copyWith({double? progress, Object? failure = _keep}) =>
      MediaUpload(
        id: id,
        doc: doc,
        video: video,
        photo: photo,
        replyToId: replyToId,
        progress: progress ?? this.progress,
        failure: identical(failure, _keep) ? this.failure : failure as Failure?,
      );

  static const _keep = Object();
}

class ChatState {
  const ChatState({
    this.latest = const [],
    this.older = const [],
    this.hidden = const {},
    this.failed = const [],
    this.loading = true,
    this.loadingOlder = false,
    this.hasMore = true,
    this.error,
    this.replyTo,
    this.sendError,
    this.clearedAt,
    this.voiceUploads = const [],
    this.editing,
    this.mediaUploads = const [],
  });

  /// Documents and videos uploading or failed (shown at the bottom).
  final List<MediaUpload> mediaUploads;

  /// The message whose text is being edited in the composer.
  final ChatMessage? editing;

  /// Voice notes uploading or failed (shown at the bottom of the chat).
  final List<VoiceUpload> voiceUploads;

  /// Everything at or before this time was cleared by the user (own view).
  final DateTime? clearedAt;
  final List<ChatMessage> latest;
  final List<ChatMessage> older;
  final Set<String> hidden;
  final List<FailedMessage> failed;
  final bool loading;
  final bool loadingOlder;
  final bool hasMore;
  final Failure? error; // stream/permission error for the whole timeline
  final ChatMessage? replyTo;
  final Failure? sendError; // transient, e.g. validation

  /// Single merged, de-duplicated timeline, newest first, minus messages the
  /// user deleted for themselves.
  List<ChatMessage> get messages {
    final seen = <String>{};
    final out = <ChatMessage>[];
    final now = DateTime.now();
    for (final m in [...latest, ...older]) {
      if (hidden.contains(m.id) || !seen.add(m.id)) continue;
      // Disappearing messages vanish at expiresAt even before the server TTL
      // job deletes the document.
      if (m.isExpired(now)) continue;
      // Pending (just-sent) messages always stay visible; the rest respect the
      // user's "clear chat" time.
      if (clearedAt != null &&
          m.status != SendStatus.sending &&
          !m.createdAt.isAfter(clearedAt!)) {
        continue;
      }
      out.add(m);
    }
    out.sort((a, b) {
      final c = b.createdAt.compareTo(a.createdAt);
      return c != 0 ? c : b.id.compareTo(a.id);
    });
    return out;
  }

  ChatState copyWith({
    List<ChatMessage>? latest,
    List<ChatMessage>? older,
    Set<String>? hidden,
    List<FailedMessage>? failed,
    bool? loading,
    bool? loadingOlder,
    bool? hasMore,
    Object? error = _keep,
    Object? replyTo = _keep,
    Object? sendError = _keep,
    Object? clearedAt = _keep,
    List<VoiceUpload>? voiceUploads,
    Object? editing = _keep,
    List<MediaUpload>? mediaUploads,
  }) => ChatState(
    mediaUploads: mediaUploads ?? this.mediaUploads,
    editing: identical(editing, _keep) ? this.editing : editing as ChatMessage?,
    latest: latest ?? this.latest,
    older: older ?? this.older,
    hidden: hidden ?? this.hidden,
    failed: failed ?? this.failed,
    loading: loading ?? this.loading,
    loadingOlder: loadingOlder ?? this.loadingOlder,
    hasMore: hasMore ?? this.hasMore,
    error: identical(error, _keep) ? this.error : error as Failure?,
    replyTo: identical(replyTo, _keep) ? this.replyTo : replyTo as ChatMessage?,
    sendError:
        identical(sendError, _keep) ? this.sendError : sendError as Failure?,
    clearedAt:
        identical(clearedAt, _keep) ? this.clearedAt : clearedAt as DateTime?,
    voiceUploads: voiceUploads ?? this.voiceUploads,
  );

  static const _keep = Object();
}

/// Owns one conversation's timeline: a bounded live window, cursor-paginated
/// history, optimistic sends (Firestore's local cache is the optimistic layer;
/// `hasPendingWrites` drives the pending state) and failed-send recovery.
class ChatViewModel extends Notifier<ChatState> {
  ChatViewModel(this.conversationId);
  final String conversationId;

  static const _uuid = Uuid();

  /// Throttle / idle timings (overridable in tests).
  static Duration typingThrottle = const Duration(seconds: 3);
  static Duration typingIdle = const Duration(seconds: 4);
  Timer? _typingIdleTimer;
  bool _typing = false;
  DateTime _lastTypingWrite = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _readTimer;
  DateTime _lastReadWrite = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastReadMarkedFor;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);
  String? get _me => ref.read(currentUidProvider);

  @override
  ChatState build() {
    final me = ref.watch(currentUidProvider);
    final repo = ref.read(chatRepositoryProvider);
    final subs = <StreamSubscription<dynamic>>[];

    if (me != null) {
      subs.add(
        repo
            .watchLatest(conversationId, AppConfig.messagePageSize)
            .listen(_onLatest, onError: _onError),
      );
      subs.add(
        repo
            .watchHidden(conversationId, me)
            .listen(
              (h) => state = state.copyWith(hidden: h),
              onError: (_) {
                /* hidden list is best-effort */
              },
            ),
      );
      // Make sure our member doc exists (chat may have been started by the
      // other participant) before we try to write read markers.
      ref
          .read(conversationRepositoryProvider)
          .ensureMember(conversationId, me)
          .catchError((Object _) {});
    }

    // Follow this user's "clear chat" time without rebuilding the notifier.
    ref.listen<AsyncValue<MemberPrefs>>(memberPrefsProvider(conversationId), (
      _,
      next,
    ) {
      final c = next.value?.clearedAt;
      if (c != state.clearedAt) {
        state = state.copyWith(clearedAt: c);
      }
    });

    ref.onDispose(() {
      _typingIdleTimer?.cancel();
      if (_typing && me != null) {
        // Best effort: don't leave "typing" showing after leaving the chat.
        repo.clearTyping(conversationId, me).catchError((Object _) {});
      }
      _readTimer?.cancel();
      for (final s in subs) {
        s.cancel();
      }
    });
    return ChatState(
      clearedAt: ref.read(memberPrefsProvider(conversationId)).value?.clearedAt,
    );
  }

  void _onError(Object e) =>
      state = state.copyWith(loading: false, error: Failure.from(e));

  void _onLatest(List<ChatMessage> msgs) {
    state = state.copyWith(
      latest: msgs,
      loading: false,
      error: null,
      // Fewer than a full window means there's no older history to fetch.
      hasMore:
          state.older.isEmpty
              ? msgs.length >= AppConfig.messagePageSize
              : state.hasMore,
    );
    _scheduleRead(msgs);
  }

  /// Throttled/batched read marker: only when the newest message is from the
  /// other person, debounced, and at most once per 5 seconds.
  void _scheduleRead(List<ChatMessage> msgs) {
    final me = _me;
    if (me == null || msgs.isEmpty) return;
    final newest = msgs.first;
    if (newest.senderId == me || newest.status == SendStatus.sending) return;
    if (_lastReadMarkedFor == newest.id) return;
    _readTimer?.cancel();
    final since = DateTime.now().difference(_lastReadWrite);
    final delay =
        since > const Duration(seconds: 5)
            ? const Duration(milliseconds: 600)
            : const Duration(seconds: 5) - since;
    _readTimer = Timer(delay, () async {
      var ok = true;
      try {
        await ref
            .read(conversationRepositoryProvider)
            .markRead(conversationId, me);
      } catch (_) {
        ok = false;
      }
      // Receipts are independent of the private read marker: a failure above
      // must not stop the sender from seeing delivered/read ticks.
      try {
        final shareRead =
            ref.read(settingsProvider).value?.readReceiptsEnabled ?? true;
        if (shareRead) {
          await _repo.markReadReceipt(conversationId, me);
        } else {
          await _repo.markDelivered(conversationId, me);
        }
      } catch (_) {
        ok = false;
      }
      if (ok) {
        _lastReadWrite = DateTime.now();
        _lastReadMarkedFor = newest.id;
      }
    });
  }

  Future<void> loadOlder() async {
    if (state.loadingOlder || !state.hasMore || state.loading) return;
    final all =
        state.messages.where((m) => m.status == SendStatus.sent).toList();
    if (all.isEmpty) return;
    final oldest = all.last;
    state = state.copyWith(loadingOlder: true);
    try {
      final page = await _repo.loadOlder(
        conversationId,
        MessageCursor(oldest.createdAt, oldest.id),
        AppConfig.messagePageSize,
      );
      state = state.copyWith(
        older: [...state.older, ...page],
        loadingOlder: false,
        hasMore:
            page.length >= AppConfig.messagePageSize &&
            !(state.clearedAt != null &&
                page.isNotEmpty &&
                !page.last.createdAt.isAfter(state.clearedAt!)),
      );
    } catch (e) {
      state = state.copyWith(loadingOlder: false, sendError: Failure.from(e));
    }
  }

  /// Clears the chat for this user only. The other participant keeps theirs.
  Future<bool> clearChat() async {
    final me = _me;
    if (me == null) return false;
    try {
      await ref
          .read(conversationRepositoryProvider)
          .clearChat(conversationId, me);
      return true;
    } catch (e) {
      state = state.copyWith(sendError: Failure.from(e));
      return false;
    }
  }

  // ------------------------------------------------------------- voice notes
  final Map<String, MediaUploader> _voiceUploaders = {};

  /// Uploads a recorded voice note and sends it. Shows progress at the bottom
  /// of the chat; a failure keeps it for retry (same id => no duplicates).
  void sendVoice(VoiceRecording rec) {
    if (_me == null) return;
    final id = _uuid.v4();
    final reply = state.replyTo?.id;
    state = state.copyWith(
      replyTo: null,
      voiceUploads: [
        ...state.voiceUploads,
        VoiceUpload(id: id, recording: rec, replyToId: reply),
      ],
    );
    _runVoice(id);
  }

  void retryVoice(String id) {
    final u = state.voiceUploads.where((x) => x.id == id).firstOrNull;
    if (u == null) return;
    _setVoice(id, (x) => x.copyWith(progress: 0, failure: null));
    _runVoice(id);
  }

  /// Cancels an upload in flight, or removes a failed one.
  void discardVoice(String id) {
    final up = _voiceUploaders.remove(id);
    up?.cancel();
    final u = state.voiceUploads.where((x) => x.id == id).firstOrNull;
    state = state.copyWith(
      voiceUploads: state.voiceUploads.where((x) => x.id != id).toList(),
    );
    if (u != null) _deleteQuietly(u.recording);
  }

  void _setVoice(String id, VoiceUpload Function(VoiceUpload) f) {
    if (!ref.mounted) return; // chat closed mid-upload: it still completes
    state = state.copyWith(
      voiceUploads: [for (final x in state.voiceUploads) x.id == id ? f(x) : x],
    );
  }

  Future<void> _runVoice(String id) async {
    final me = _me;
    final u = state.voiceUploads.where((x) => x.id == id).firstOrNull;
    if (me == null || u == null) return;
    final uploader = ref.read(mediaUploaderFactoryProvider)();
    _voiceUploaders[id] = uploader;
    try {
      await SendVoiceMessageUseCase(uploader, _repo).call(
        conversationId: conversationId,
        senderId: me,
        messageId: id,
        recording: u.recording,
        replyToId: u.replyToId,
        onProgress: (p) => _setVoice(id, (x) => x.copyWith(progress: p)),
      );
      _voiceUploaders.remove(id);
      _deleteQuietly(u.recording);
      if (!ref.mounted) return;
      state = state.copyWith(
        voiceUploads: state.voiceUploads.where((x) => x.id != id).toList(),
      );
    } catch (e) {
      _voiceUploaders.remove(id);
      if (!ref.mounted) return;
      final f = Failure.from(e);
      // A user cancel removes the item; anything else keeps it for retry.
      if (f is UploadFailure && f.reason == UploadReason.cancelled) {
        if (state.voiceUploads.any((x) => x.id == id)) discardVoice(id);
      } else if (state.voiceUploads.any((x) => x.id == id)) {
        _setVoice(id, (x) => x.copyWith(failure: f));
      }
    }
  }

  // ----------------------------------------------------- documents and videos
  final Map<String, MediaUploader> _mediaUploaders = {};

  void sendDocument(PickedDocument doc) => _startMedia(
    MediaUpload(id: _uuid.v4(), doc: doc, replyToId: state.replyTo?.id),
  );

  /// Photo from the preview screen: compressed and uploaded in the
  /// background while the chat shows it with a progress ring.
  void sendPhoto(PickedPhoto photo, {String? replyToId}) => _startMedia(
    MediaUpload(
      id: _uuid.v4(),
      photo: photo,
      replyToId: replyToId ?? state.replyTo?.id,
    ),
  );

  void sendVideo(PickedVideo video) => _startMedia(
    MediaUpload(id: _uuid.v4(), video: video, replyToId: state.replyTo?.id),
  );

  void _startMedia(MediaUpload u) {
    if (_me == null) return;
    state = state.copyWith(
      replyTo: null,
      mediaUploads: [...state.mediaUploads, u],
    );
    _runMedia(u.id);
  }

  void retryMedia(String id) {
    if (!state.mediaUploads.any((x) => x.id == id)) return;
    _setMedia(id, (x) => x.copyWith(progress: 0, failure: null));
    _runMedia(id);
  }

  /// Cancels an upload in flight, or removes a failed one.
  void discardMedia(String id) {
    _mediaUploaders.remove(id)?.cancel();
    state = state.copyWith(
      mediaUploads: state.mediaUploads.where((x) => x.id != id).toList(),
    );
  }

  void _setMedia(String id, MediaUpload Function(MediaUpload) f) {
    if (!ref.mounted) return;
    state = state.copyWith(
      mediaUploads: [for (final x in state.mediaUploads) x.id == id ? f(x) : x],
    );
  }

  Future<void> _runMedia(String id) async {
    final me = _me;
    final u = state.mediaUploads.where((x) => x.id == id).firstOrNull;
    if (me == null || u == null) return;
    final uploader = ref.read(mediaUploaderFactoryProvider)();
    _mediaUploaders[id] = uploader;
    final useCase = SendMediaMessageUseCase(uploader, _repo);
    void progress(double p) => _setMedia(id, (x) => x.copyWith(progress: p));
    try {
      if (u.photo != null) {
        await SendImageMessageUseCase(
          ref.read(imageProcessorProvider),
          uploader,
          _repo,
        )(
          conversationId: conversationId,
          senderId: me,
          messageId: id,
          source: u.photo!.file,
          caption: u.photo!.caption,
          replyToId: u.replyToId,
          onProgress: progress,
        );
      } else if (u.video != null) {
        await useCase.sendVideo(
          conversationId: conversationId,
          senderId: me,
          messageId: id,
          video: u.video!,
          replyToId: u.replyToId,
          onProgress: progress,
        );
      } else {
        await useCase.sendDocument(
          conversationId: conversationId,
          senderId: me,
          messageId: id,
          doc: u.doc!,
          replyToId: u.replyToId,
          onProgress: progress,
        );
      }
      _mediaUploaders.remove(id);
      if (!ref.mounted) return;
      state = state.copyWith(
        mediaUploads: state.mediaUploads.where((x) => x.id != id).toList(),
      );
    } catch (e) {
      _mediaUploaders.remove(id);
      if (!ref.mounted) return;
      final f = Failure.from(e);
      if (f is UploadFailure && f.reason == UploadReason.cancelled) {
        if (state.mediaUploads.any((x) => x.id == id)) discardMedia(id);
      } else if (state.mediaUploads.any((x) => x.id == id)) {
        _setMedia(id, (x) => x.copyWith(failure: f));
      }
    }
  }

  void _deleteQuietly(VoiceRecording r) {
    try {
      r.file.deleteSync();
    } catch (_) {}
  }

  void setReplyTo(ChatMessage? m) =>
      state = state.copyWith(replyTo: m, editing: null);

  /// Turns [m]'s bubble into an inline editor (replaces any reply).
  void startEdit(ChatMessage m) =>
      state = state.copyWith(editing: m, replyTo: null, sendError: null);

  void cancelEdit() => state = state.copyWith(editing: null);
  void clearSendError() => state = state.copyWith(sendError: null);

  /// Sends [text]. Returns false if rejected by local validation (the caller
  /// keeps the draft in the composer in that case).
  /// Call on every composer change. Writes a typing signal at most once per
  /// [typingThrottle], and clears it when the text is emptied or after
  /// [typingIdle] without typing. Respects the "Last seen & online" privacy
  /// switch (off = nothing is sent).
  void typingChanged(String text) {
    final me = _me;
    if (me == null) return;
    final enabled = ref.read(settingsProvider).value?.showLastSeen ?? false;
    if (!enabled) return;
    if (text.trim().isEmpty) {
      _stopTyping();
      return;
    }
    _typingIdleTimer?.cancel();
    _typingIdleTimer = Timer(typingIdle, _stopTyping);
    if (DateTime.now().difference(_lastTypingWrite) >= typingThrottle) {
      _lastTypingWrite = DateTime.now();
      _typing = true;
      _repo.setTyping(conversationId, me).catchError((Object _) {});
    }
  }

  void _stopTyping() {
    _typingIdleTimer?.cancel();
    final me = _me;
    if (!_typing || me == null) return;
    _typing = false;
    _lastTypingWrite = DateTime.fromMillisecondsSinceEpoch(0);
    _repo.clearTyping(conversationId, me).catchError((Object _) {});
  }

  bool sendText(String text) {
    final me = _me;
    if (me == null) return false;
    try {
      FieldValidators.messageText(text);
    } on ValidationFailure catch (f) {
      state = state.copyWith(sendError: f);
      return false;
    }
    _stopTyping();
    final id = _uuid.v4();
    final reply = state.replyTo?.id;
    state = state.copyWith(replyTo: null, sendError: null);
    _dispatch(id, text.trim(), reply);
    return true;
  }

  /// Saves the inline edit of [state.editing]. Returns false if the text is
  /// invalid (the edit stays open).
  bool saveEdit(String raw) {
    final m = state.editing;
    if (m == null) return false;
    try {
      FieldValidators.messageText(raw);
    } on ValidationFailure catch (f) {
      state = state.copyWith(sendError: f);
      return false;
    }
    _saveEdit(m, raw.trim());
    return true;
  }

  Future<void> _saveEdit(ChatMessage m, String text) async {
    state = state.copyWith(editing: null);
    if (text == (m.text ?? '')) return; // nothing changed
    if (!m.canEdit(_me ?? '')) {
      state = state.copyWith(sendError: const PermissionFailure());
      return;
    }
    try {
      await _repo.editMessage(conversationId, m.id, text);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(sendError: Failure.from(e));
    }
  }

  void _dispatch(String id, String text, String? replyToId) {
    final me = _me;
    if (me == null) return;
    // Intentionally not awaited: offline writes stay queued by Firestore and
    // show as "sending" until acknowledged; only rejections surface here.
    unawaited(
      ref
          .read(sendTextUseCaseProvider)
          .call(
            conversationId: conversationId,
            messageId: id,
            senderId: me,
            text: text,
            replyToId: replyToId,
          )
          .then((_) {
            state = state.copyWith(
              failed: state.failed.where((f) => f.id != id).toList(),
            );
          })
          .catchError((Object e) {
            final failure = Failure.from(e);
            final others = state.failed.where((f) => f.id != id).toList();
            state = state.copyWith(
              failed: [
                ...others,
                FailedMessage(
                  id: id,
                  text: text,
                  replyToId: replyToId,
                  failure: failure,
                  createdAt: DateTime.now(),
                ),
              ],
            );
          }),
    );
  }

  /// Retry re-uses the same message id, so it can never duplicate.
  void retry(String id) {
    final f = state.failed.where((x) => x.id == id).firstOrNull;
    if (f == null) return;
    state = state.copyWith(
      failed: state.failed.where((x) => x.id != id).toList(),
    );
    _dispatch(f.id, f.text, f.replyToId);
  }

  void discard(String id) =>
      state = state.copyWith(
        failed: state.failed.where((x) => x.id != id).toList(),
      );

  /// Hides messages from this user's own view only.
  Future<void> deleteForMe(Iterable<String> messageIds) async {
    final me = _me;
    if (me == null) return;
    try {
      for (final id in messageIds) {
        await _repo.hideMessage(conversationId, me, id);
      }
    } catch (e) {
      state = state.copyWith(sendError: Failure.from(e));
    }
  }

  /// Wipes the content for everyone. Only the sender's recent messages are
  /// eligible (enforced here and by the security rules).
  Future<void> deleteForEveryone(Iterable<String> messageIds) async {
    final me = _me;
    if (me == null) return;
    final byId = {
      for (final m in [...state.latest, ...state.older]) m.id: m,
    };
    try {
      for (final id in messageIds) {
        final m = byId[id];
        if (m == null || !m.canDeleteForEveryone(me)) continue;
        await _repo.deleteForEveryone(conversationId, id);
      }
    } catch (e) {
      state = state.copyWith(sendError: Failure.from(e));
    }
  }

  Future<void> react(String messageId, String? emoji) async {
    final me = _me;
    if (me == null) return;
    try {
      await _repo.setReaction(conversationId, messageId, me, emoji);
    } catch (e) {
      state = state.copyWith(sendError: Failure.from(e));
    }
  }
}

final chatViewModelProvider = NotifierProvider.autoDispose
    .family<ChatViewModel, ChatState, String>(ChatViewModel.new);

/// Live reactions for one message; only subscribed while its bubble is built.
final reactionsProvider = StreamProvider.autoDispose.family<
  Map<String, String>,
  ({String cid, String mid})
>((ref, k) => ref.watch(chatRepositoryProvider).watchReactions(k.cid, k.mid));
