import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/theme/hushlo_colors.dart';
import '../../../../core/utils/app_settings.dart';
import '../../../../core/utils/connectivity.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/hushlo_back_button.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../attachments/presentation/viewmodels/attachment_providers.dart';
import '../../../auth/presentation/viewmodels/auth_providers.dart';
import '../../../conversations/domain/entities/conversation.dart';
import '../../../conversations/presentation/viewmodels/conversation_providers.dart';
import '../../../notifications/presentation/push_controller.dart';
import '../../../presence/domain/presence_label.dart';
import '../../../presence/presentation/presence_controller.dart';
import '../../../privacy_settings/presentation/viewmodels/settings_providers.dart';
import '../../../profile/presentation/viewmodels/profile_providers.dart';
import '../../../safety/presentation/viewmodels/safety_providers.dart';
import '../../../safety/presentation/widgets/report_dialog.dart';
import '../../../groups/presentation/widgets/system_message_row.dart';
import '../../domain/entities/chat_message.dart';
import '../viewmodels/chat_view_model.dart';
import '../../../saved/presentation/viewmodels/saved_providers.dart';
import '../../domain/message_search.dart';
import '../../../voice/domain/voice_models.dart';
import '../../../files/domain/file_rules.dart';
import '../../../files/domain/media_picker.dart';
import '../../../files/presentation/viewmodels/file_providers.dart';
import '../../../chat_theme/presentation/chat_theme_scope.dart';
import '../../../chat_theme/presentation/chat_theme_sheet.dart';
import '../widgets/composer.dart';
import '../widgets/pending_media_bubble.dart';
import '../widgets/upload_bubble.dart';
import '../widgets/inline_edit_bubble.dart';
import '../widgets/message_bubble.dart';

const _reactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

/// The chat, drawn with this user's chosen theme (bubble colour, wallpaper).
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  Widget build(BuildContext context) => ChatThemeScope(
    conversationId: conversationId,
    child: _ChatView(conversationId: conversationId),
  );
}

class _ChatView extends ConsumerStatefulWidget {
  const _ChatView({required this.conversationId});
  final String conversationId;

  @override
  ConsumerState<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<_ChatView> {
  final _scroll = ScrollController();
  late final ActiveConversation _active;
  bool _showNewIndicator = false;

  /// One key per message so a reply can scroll to its original.
  final Map<String, GlobalKey> _itemKeys = {};
  String? _highlightId;

  // In-chat search: query, the match currently shown, and a loading flag
  // while older history is fetched to look for more matches.
  bool _searching = false;
  String _query = '';
  String? _matchId;
  bool _searchLoading = false;
  Timer? _searchDebounce;

  /// The heavy conversation content is built only after the route transition
  /// (and the avatar Hero) finishes, so opening a chat stays smooth.
  bool _ready = false;
  bool _routeHooked = false;
  Timer? _highlightTimer;

  /// Selected message ids (selection mode is active while non-empty).
  final Set<String> _selected = {};

  String get _cid => widget.conversationId;
  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _active = ref.read(activeConversationProvider.notifier);
    Future.microtask(() => _setActive(_cid));
    _scroll.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeHooked) return;
    _routeHooked = true;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.status == AnimationStatus.completed) {
      _ready = true;
      return;
    }
    void listener(AnimationStatus st) {
      if (st == AnimationStatus.completed || st == AnimationStatus.dismissed) {
        animation.removeStatusListener(listener);
        if (mounted && !_ready) setState(() => _ready = true);
      }
    }

    animation.addStatusListener(listener);
    // Safety net if the animation never reports completion.
    Timer(const Duration(milliseconds: 900), () {
      if (mounted && !_ready) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _searchDebounce?.cancel();
    _scroll.dispose();
    Future.microtask(() => _setActive(null));
    super.dispose();
  }

  /// Tracks the open conversation (suppresses its foreground alerts). Safe if
  /// the provider scope has already been disposed.
  void _setActive(String? id) {
    try {
      _active.set(id);
    } catch (_) {}
  }

  bool get _atBottom => !_scroll.hasClients || _scroll.position.pixels < 80;

  void _onScroll() {
    final p = _scroll.position;
    if (p.pixels > p.maxScrollExtent - 400) {
      ref.read(chatViewModelProvider(_cid).notifier).loadOlder();
    }
    if (_atBottom && _showNewIndicator) {
      setState(() => _showNewIndicator = false);
    }
  }

  void _jumpToBottom() {
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    setState(() => _showNewIndicator = false);
  }

  /// Keep what the user is reading in place when new messages arrive.
  void _onNewestChanged(ChatState? prev, ChatState next, String me) {
    final pn = prev?.messages.firstOrNull;
    final nn = next.messages.firstOrNull;
    if (nn == null || pn == null || pn.id == nn.id) return;
    if (!_scroll.hasClients) return;
    final wasAtBottom = _atBottom;
    final oldMax = _scroll.position.maxScrollExtent;
    final oldPixels = _scroll.position.pixels;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (wasAtBottom || nn.senderId == me) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else {
        final delta = _scroll.position.maxScrollExtent - oldMax;
        if (delta > 0) _scroll.jumpTo(oldPixels + delta);
        setState(() => _showNewIndicator = true);
      }
    });
  }

  // ---------------------------------------------------------------- selection

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _clearSelection() => setState(_selected.clear);

  List<ChatMessage> _selectedMessages(ChatState state) =>
      state.messages.where((m) => _selected.contains(m.id)).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Future<void> _deleteSelected(ChatState state, String me) async {
    final l = context.l10n;
    final vm = ref.read(chatViewModelProvider(_cid).notifier);
    final msgs = _selectedMessages(state);
    if (msgs.isEmpty) return;
    final everyone = msgs.every((m) => m.canDeleteForEveryone(me));

    final choice = await showModalBottomSheet<String>(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.deleteMessagesTitle(msgs.length),
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (everyone) ...[
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(ctx, 'everyone'),
                      style: FilledButton.styleFrom(
                        backgroundColor: ctx.colors.error,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.delete_forever_rounded),
                      label: Text(l.deleteForEveryone),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
                      child: Text(
                        l.deleteForEveryoneHelp,
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ),
                  ],
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(ctx, 'me'),
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(l.deleteForMeOnly),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(l.cancel),
                  ),
                ],
              ),
            ),
          ),
    );
    if (choice == null) return;
    final ids = msgs.map((m) => m.id).toList();
    _clearSelection();
    if (choice == 'everyone') {
      await vm.deleteForEveryone(ids);
    } else {
      await vm.deleteForMe(ids);
    }
  }

  void _copySelected(ChatState state) {
    final l = context.l10n;
    final text = _selectedMessages(state)
        .where((m) => !m.deleted && (m.text ?? '').isNotEmpty)
        .map((m) => m.text!)
        .join('\n');
    _clearSelection();
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l.copied)));
  }

  /// Copies the selected text messages into "Saved messages" (private).
  Future<void> _saveSelected(ChatState state, String me) async {
    final l = context.l10n;
    final msgs =
        _selectedMessages(
          state,
        ).where((m) => !m.deleted && (m.text ?? '').trim().isNotEmpty).toList();
    _clearSelection();
    if (msgs.isEmpty) return;
    final repo = ref.read(savedRepositoryProvider);
    try {
      for (final m in msgs) {
        final name =
            m.senderId == me
                ? l.you
                : (ref
                        .read(profileByUidProvider(m.senderId))
                        .value
                        ?.displayName ??
                    '');
        await repo.add(me, m.text!.trim(), sourceName: name);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.savedCount(msgs.length))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.savedFailed)));
      }
    }
  }

  // ------------------------------------------------------------------ actions

  Future<void> _attach() async {
    final l = context.l10n;
    final choice = await showModalBottomSheet<_Attach>(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  runSpacing: 18,
                  spacing: 6,
                  children: [
                    _AttachOption(
                      icon: Icons.photo_library_rounded,
                      label: l.chooseFromGallery,
                      colors: const [Color(0xFF8C83F6), Color(0xFF5B4FE0)],
                      onTap: () => Navigator.pop(ctx, _Attach.gallery),
                    ),
                    _AttachOption(
                      icon: Icons.photo_camera_rounded,
                      label: l.takePhoto,
                      colors: const [Color(0xFF43CDB8), Color(0xFF1E8FA8)],
                      onTap: () => Navigator.pop(ctx, _Attach.camera),
                    ),
                    _AttachOption(
                      icon: Icons.videocam_rounded,
                      label: l.attachVideo,
                      colors: const [Color(0xFFF58FB5), Color(0xFFD9467C)],
                      onTap: () => Navigator.pop(ctx, _Attach.video),
                    ),
                    _AttachOption(
                      icon: Icons.video_camera_back_rounded,
                      label: l.attachRecordVideo,
                      colors: const [Color(0xFF7BC8F6), Color(0xFF2F8FD8)],
                      onTap: () => Navigator.pop(ctx, _Attach.recordVideo),
                    ),
                    _AttachOption(
                      icon: Icons.insert_drive_file_rounded,
                      label: l.attachDocument,
                      colors: const [Color(0xFFF6B94A), Color(0xFFEF8A3C)],
                      onTap: () => Navigator.pop(ctx, _Attach.document),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
    if (choice == null || !mounted) return;
    final vm = ref.read(chatViewModelProvider(_cid).notifier);
    try {
      switch (choice) {
        case _Attach.gallery || _Attach.camera:
          final x = await ref
              .read(imagePickerProvider)
              .pickImage(
                source:
                    choice == _Attach.camera
                        ? ImageSource.camera
                        : ImageSource.gallery,
              );
          if (x == null || !mounted) return;
          final replyId = ref.read(chatViewModelProvider(_cid)).replyTo?.id;
          context.push(
            '/chat/$_cid/attachment',
            extra: {'path': x.path, 'replyTo': replyId},
          );
        case _Attach.video || _Attach.recordVideo:
          final v = await ref
              .read(mediaPickerProvider)
              .pickVideo(
                choice == _Attach.recordVideo
                    ? VideoSource.camera
                    : VideoSource.gallery,
              );
          if (v != null && mounted) vm.sendVideo(v);
        case _Attach.document:
          final d = await ref.read(mediaPickerProvider).pickDocument();
          if (d != null && mounted) vm.sendDocument(d);
      }
    } on FilePickException catch (e) {
      if (!mounted) return;
      final msg = switch (e.problem) {
        FileProblem.unsupportedType => l.fileUnsupported,
        FileProblem.tooLarge => l.fileTooLarge,
        FileProblem.empty => l.fileEmpty,
        FileProblem.videoTooLong => l.videoTooLong,
        FileProblem.videoTooShort => l.videoTooShort,
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.photoPermissionDenied),
          action: SnackBarAction(
            label: l.openSettings,
            onPressed: () => ref.read(openAppSettingsProvider)(),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.filePickFailed)));
    }
  }

  Future<void> _confirmBlock(String other, String name) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l.blockTitle(name)),
            content: Text(l.blockBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l.block),
              ),
            ],
          ),
    );
    if (ok != true || !mounted) return;
    final me = ref.read(currentUidProvider)!;
    try {
      await ref.read(safetyRepositoryProvider).block(me, other);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage(l, Failure.from(e)))),
      );
    }
  }

  Future<void> _confirmClear(String name) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l.clearChatTitle),
            content: Text(l.clearChatBody(name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(96, 48),
                  backgroundColor: ctx.colors.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l.clearAction),
              ),
            ],
          ),
    );
    if (ok != true || !mounted) return;
    final done =
        await ref.read(chatViewModelProvider(_cid).notifier).clearChat();
    if (done && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.chatCleared)));
    }
  }

  Future<void> _mute(String me) async {
    final l = context.l10n;
    final repo = ref.read(conversationRepositoryProvider);
    final choice = await showModalBottomSheet<Duration?>(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (label, d) in [
                  (l.mute1h, const Duration(hours: 1)),
                  (l.mute8h, const Duration(hours: 8)),
                  (l.mute1w, const Duration(days: 7)),
                  (l.muteForever, const Duration(days: 36500)),
                ])
                  ListTile(
                    title: Text(label),
                    onTap: () => Navigator.pop(ctx, d),
                  ),
              ],
            ),
          ),
    );
    if (choice == null) return;
    try {
      await repo.setMutedUntil(_cid, me, DateTime.now().add(choice));
    } catch (_) {}
  }

  // ------------------------------------------------------------------ search

  List<ChatMessage> _matches() =>
      searchMessages(ref.read(chatViewModelProvider(_cid)).messages, _query);

  void _openSearch() {
    _clearSelection();
    setState(() {
      _searching = true;
      _query = '';
      _matchId = null;
    });
  }

  void _closeSearch() {
    _searchDebounce?.cancel();
    setState(() {
      _searching = false;
      _query = '';
      _matchId = null;
      _searchLoading = false;
    });
  }

  void _onQueryChanged(String q) {
    _searchDebounce?.cancel();
    setState(() {
      _query = q;
      _matchId = null;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted || !_searching) return;
      var matches = _matches();
      if (matches.isEmpty) {
        await _searchOlder(0);
        matches = _matches();
      }
      if (mounted && matches.isNotEmpty) _focusMatch(matches.first.id);
    });
  }

  void _focusMatch(String id) {
    setState(() => _matchId = id);
    _scrollToMessage(id);
  }

  /// Loads older pages until a new match appears (or history/limit ends).
  Future<void> _searchOlder(int have) async {
    final vm = ref.read(chatViewModelProvider(_cid).notifier);
    setState(() => _searchLoading = true);
    try {
      for (var i = 0; i < 8; i++) {
        final st = ref.read(chatViewModelProvider(_cid));
        if (!st.hasMore || !mounted || !_searching) break;
        await vm.loadOlder();
        if (_matches().length > have) break;
      }
    } finally {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  /// [dir] +1 = next older match, -1 = next newer one.
  Future<void> _stepMatch(int dir) async {
    var matches = _matches();
    if (matches.isEmpty) return;
    var pos = matches.indexWhere((m) => m.id == _matchId);
    if (pos == -1) pos = dir > 0 ? -1 : matches.length;
    var next = pos + dir;
    if (next >= matches.length) {
      await _searchOlder(matches.length);
      matches = _matches();
      if (next >= matches.length) return; // no older matches
    }
    if (next < 0) return;
    _focusMatch(matches[next].id);
  }

  AppBar _searchBar() {
    final l = context.l10n;
    final c = context.colors;
    final matches = _matches();
    final pos = matches.indexWhere((m) => m.id == _matchId);
    final hasQuery = _query.trim().isNotEmpty;
    final hasMore = ref.read(chatViewModelProvider(_cid)).hasMore;
    return AppBar(
      backgroundColor: c.surface,
      leading: IconButton(
        tooltip: l.searchClose,
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: _closeSearch,
      ),
      titleSpacing: 0,
      title: TextField(
        autofocus: true,
        textInputAction: TextInputAction.search,
        onChanged: _onQueryChanged,
        decoration: InputDecoration(
          hintText: l.searchHint,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
      actions: [
        if (hasQuery)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              child:
                  _searchLoading
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Text(
                        matches.isEmpty
                            ? (hasMore ? '…' : l.searchNoResults)
                            : l.searchCount(
                              pos < 0 ? 1 : pos + 1,
                              matches.length,
                            ),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
                      ),
            ),
          ),
        IconButton(
          tooltip: l.searchOlderTooltip,
          icon: const Icon(Icons.keyboard_arrow_up_rounded),
          onPressed:
              matches.isEmpty || _searchLoading ? null : () => _stepMatch(1),
        ),
        IconButton(
          tooltip: l.searchNewerTooltip,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          onPressed:
              matches.isEmpty || _searchLoading ? null : () => _stepMatch(-1),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------- build

  AppBar _selectionBar(ChatState state, String me) {
    final l = context.l10n;
    final c = context.colors;
    final msgs = _selectedMessages(state);
    final single = msgs.length == 1 ? msgs.first : null;
    final vm = ref.read(chatViewModelProvider(_cid).notifier);
    final anyText = msgs.any((m) => !m.deleted && (m.text ?? '').isNotEmpty);
    return AppBar(
      backgroundColor: c.primaryContainer,
      leading: IconButton(
        tooltip: l.cancelSelection,
        icon: const Icon(Icons.close_rounded),
        onPressed: _clearSelection,
      ),
      title: Text(l.selectedCount(_selected.length)),
      actions: [
        if (single != null && !single.deleted)
          IconButton(
            tooltip: l.reply,
            icon: const Icon(Icons.reply_rounded),
            onPressed: () {
              vm.setReplyTo(single);
              _clearSelection();
            },
          ),
        if (single != null && single.canEdit(me))
          IconButton(
            tooltip: l.editMessage,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              vm.startEdit(single);
              _clearSelection();
            },
          ),
        if (single != null &&
            !single.deleted &&
            !single.isSystem &&
            single.senderId == me &&
            (ref.read(conversationProvider(_cid)).value?.isGroup ?? false))
          IconButton(
            tooltip: l.messageInfo,
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {
              final id = single.id;
              _clearSelection();
              context.push('/chat/$_cid/message/$id');
            },
          ),
        if (anyText)
          IconButton(
            tooltip: l.copyMessages,
            icon: const Icon(Icons.copy_rounded),
            onPressed: () => _copySelected(state),
          ),
        if (anyText)
          IconButton(
            tooltip: l.saveToSaved,
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: () => _saveSelected(state, me),
          ),
        IconButton(
          tooltip: l.deleteForMe,
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () => _deleteSelected(state, me),
        ),
      ],
    );
  }

  /// Briefly tints a message (used after jumping to a quoted original).
  void _flash(String id) {
    if (_searching) return; // the current search match stays tinted instead
    _highlightTimer?.cancel();
    setState(() => _highlightId = id);
    _highlightTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _highlightId = null);
    });
  }

  /// Scrolls to [id], loading older history first when it isn't loaded yet,
  /// then highlights it. Works with lazily built, variable-height items by
  /// jumping near the estimated offset until the item is built.
  Future<void> _scrollToMessage(String id) async {
    final l = context.l10n;
    final vm = ref.read(chatViewModelProvider(_cid).notifier);
    for (var attempt = 0; attempt < 14; attempt++) {
      if (!mounted) return;
      final state = ref.read(chatViewModelProvider(_cid));
      final msgs = state.messages;
      final idx = msgs.indexWhere((m) => m.id == id);
      if (idx == -1) {
        if (!state.hasMore && !state.loadingOlder) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l.originalUnavailable)));
          return;
        }
        await vm.loadOlder();
        await WidgetsBinding.instance.endOfFrame;
        continue;
      }
      final ctx = _itemKeys[id]?.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(
          ctx,
          alignment: 0.35,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
        );
        if (mounted) _flash(id);
        return;
      }
      if (!_scroll.hasClients) return;
      // Not built yet: jump near where it should be (reversed list: offset 0
      // is the newest message) and try again on the next frame.
      final estimate = (idx + state.failed.length) * (92.0 + attempt * 14);
      _scroll.jumpTo(estimate.clamp(0.0, _scroll.position.maxScrollExtent));
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  void _toggleReactionFor(String messageId, String emoji, String me) {
    final current =
        ref.read(reactionsProvider((cid: _cid, mid: messageId))).value?[me];
    _toggleReaction(messageId, emoji, current);
  }

  void _toggleReaction(String messageId, String emoji, String? current) {
    final vm = ref.read(chatViewModelProvider(_cid).notifier);
    vm.react(messageId, nextReaction(current, emoji));
  }

  Widget _reactionStrip(ChatMessage m) {
    final l = context.l10n;
    final c = context.colors;
    final me = ref.read(currentUidProvider);
    final mine =
        ref.watch(reactionsProvider((cid: _cid, mid: m.id))).value?[me];
    return Material(
      color: c.surface,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final e in _reactionEmojis)
              Semantics(
                button: true,
                selected: mine == e,
                label: mine == e ? '${l.removeReaction} $e' : '${l.react} $e',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    _toggleReaction(m.id, e, mine);
                    _clearSelection();
                  },
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: mine == e ? c.primaryContainer : null,
                    ),
                    child: Center(
                      child: Text(e, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final me = ref.watch(currentUidProvider);
    if (me == null) return const SizedBox.shrink();

    final conv = ref.watch(conversationProvider(_cid));
    final state = ref.watch(chatViewModelProvider(_cid));
    if ([...state.latest, ...state.older].any((m) => m.expiresAt != null)) {
      ref.watch(expiryClockProvider); // rebuild so expired messages vanish
    }
    final vm = ref.read(chatViewModelProvider(_cid).notifier);
    final prefs =
        ref.watch(memberPrefsProvider(_cid)).value ?? const MemberPrefs();
    final online = ref.watch(isOnlineProvider).value ?? true;
    final blocked = ref.watch(blockedUidsProvider).value ?? const {};
    final convValue = conv.value;
    final isGroup = convValue?.isGroup ?? _cid.startsWith('g_');
    final otherUid =
        isGroup
            ? ''
            : (convValue?.otherUid(me) ??
                _cid.split('_').firstWhere((u) => u != me, orElse: () => ''));
    final deleted = isGroup ? false : (convValue?.otherDeleted(me) ?? false);
    // Removed from the group: the conversation can no longer be read.
    final removedFromGroup = isGroup && conv.hasError;
    final otherProfile =
        otherUid.isEmpty
            ? null
            : ref.watch(profileByUidProvider(otherUid)).value;
    final name =
        isGroup
            ? (convValue?.name ?? '')
            : (deleted || (otherProfile == null && !conv.isLoading)
                ? l.deletedAccount
                : (otherProfile?.displayName ?? ''));
    final iBlocked = blocked.contains(otherUid);
    final settings = ref.watch(settingsProvider).value;
    final peerReceipts =
        otherUid.isEmpty
            ? null
            : ref
                .watch(peerReceiptsProvider((cid: _cid, peer: otherUid)))
                .value;
    final receiptsOn = settings?.readReceiptsEnabled ?? true;
    final groupReceipts =
        isGroup
            ? (ref.watch(groupReceiptsProvider(_cid)).value ??
                const <String, Receipts>{})
            : const <String, Receipts>{};
    final groupOthers =
        isGroup
            ? (convValue?.othersOf(me) ?? const <String>[])
            : const <String>[];
    SendStatus statusOf(ChatMessage m) {
      final st =
          isGroup
              ? resolveGroupStatus(m, groupReceipts, groupOthers)
              : resolveStatus(m, peerReceipts);
      // Reciprocity: if I don't share read receipts, I don't see them either.
      return (!receiptsOn && st == SendStatus.read) ? SendStatus.delivered : st;
    }

    // Online / last seen (reciprocal: hidden when I hide mine).
    final showPresence =
        (settings?.showLastSeen ?? false) &&
        !deleted &&
        otherUid.isNotEmpty &&
        !iBlocked;
    final lastActive =
        showPresence ? ref.watch(peerPresenceProvider(otherUid)).value : null;
    final now = ref.watch(presenceClockProvider).value ?? DateTime.now();
    final locale = Localizations.localeOf(context).toString();
    final presence =
        showPresence ? presenceLabel(l, lastActive, locale, now: now) : null;
    final isOnlineNow = showPresence && isOnline(lastActive, now);

    // "typing…" (same privacy switch as last seen; expires without new signals)
    final typingAt =
        showPresence
            ? ref.watch(peerTypingProvider((cid: _cid, peer: otherUid))).value
            : null;
    final directTyping =
        typingAt != null
            ? isTypingNow(typingAt, ref.watch(typingClockProvider).value)
            : false;
    final groupSignals =
        (isGroup && (settings?.showLastSeen ?? false))
            ? ref.watch(typingUsersProvider(_cid)).value
            : null;
    final groupTypingUids = typingUids(
      groupSignals,
      me,
      (groupSignals?.isNotEmpty ?? false)
          ? ref.watch(typingClockProvider).value
          : null,
    );
    final typingNow = directTyping || groupTypingUids.isNotEmpty;

    ref.listen<ChatState>(chatViewModelProvider(_cid), (prev, next) {
      _onNewestChanged(prev, next, me);
      final err = next.sendError;
      if (err != null && prev?.sendError != err) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failureMessage(l, err))));
        vm.clearSendError();
      }
    });

    final messages = state.messages;
    final byId = {
      for (final m in [...state.latest, ...state.older]) m.id: m,
    };
    // Drop keys for messages that are no longer loaded.
    _itemKeys.removeWhere((id, _) => !byId.containsKey(id));
    final failed = [...state.failed]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final typingExtra = typingNow ? 1 : 0;
    final uploads = state.voiceUploads;
    final media = state.mediaUploads;
    final itemCount =
        typingExtra +
        uploads.length +
        media.length +
        failed.length +
        messages.length +
        (state.loadingOlder ? 1 : 0);

    Widget body;
    if (state.loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (state.error != null && messages.isEmpty) {
      body = ErrorState(error: state.error!);
    } else if (messages.isEmpty &&
        failed.isEmpty &&
        uploads.isEmpty &&
        media.isEmpty) {
      body = Column(
        children: [
          Expanded(
            child: EmptyState(
              illustration: 'assets/illustrations/say_hello.png',
              icon: Icons.waving_hand_outlined,
              title: l.chatEmptyTitle,
              message: l.chatEmptyBody(name),
            ),
          ),
          _PrivacyNote(text: l.chatPrivacyNote),
        ],
      );
    } else {
      body = ListView.builder(
        controller: _scroll,
        reverse: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: itemCount,
        itemBuilder: (ctx, rawIndex) {
          var i = rawIndex;
          if (typingNow) {
            if (i == 0) return const _TypingBubble();
            i -= 1;
          }
          if (i < uploads.length) {
            final u = uploads[uploads.length - 1 - i];
            return UploadBubble(
              label:
                  '${l.voiceMessage} · ${formatVoiceDuration(u.recording.durationMs)}',
              icon: Icons.mic_rounded,
              progress: u.progress,
              failed: u.failed,
              rejected: u.failure is PermissionFailure,
              onRetry: () => vm.retryVoice(u.id),
              onDiscard: () => vm.discardVoice(u.id),
            );
          }
          i -= uploads.length;
          if (i < media.length) {
            final u = media[media.length - 1 - i];
            return PendingMediaBubble(
              upload: u,
              onRetry: () => vm.retryMedia(u.id),
              onDiscard: () => vm.discardMedia(u.id),
            );
          }
          i -= media.length;
          if (i < failed.length) {
            final f = failed[failed.length - 1 - i];
            return FailedBubble(
              failed: f,
              onRetry: () => vm.retry(f.id),
              onDiscard: () => vm.discard(f.id),
            );
          }
          final mi = i - failed.length;
          if (mi >= messages.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final m = messages[mi];
          final older = mi + 1 < messages.length ? messages[mi + 1] : null;
          final showDay =
              older == null ||
              !DateFormatter.isSameDay(older.createdAt, m.createdAt);
          if (m.isSystem) {
            return Column(
              key: _itemKeys.putIfAbsent(m.id, GlobalKey.new),
              children: [
                if (showDay)
                  _DaySeparator(
                    DateFormatter.daySeparator(
                      m.createdAt,
                      locale,
                      today: l.today,
                      yesterday: l.yesterday,
                    ),
                  ),
                SystemMessageRow(message: m, me: me),
              ],
            );
          }
          final mine = m.senderId == me;
          final newer = mi > 0 ? messages[mi - 1] : null;
          bool sameRun(ChatMessage a, ChatMessage b) =>
              !a.isSystem &&
              !b.isSystem &&
              a.senderId == b.senderId &&
              a.createdAt.difference(b.createdAt).abs() <
                  const Duration(minutes: 5) &&
              DateFormatter.isSameDay(a.createdAt, b.createdAt);
          final groupStart = older == null || showDay || !sameRun(older, m);
          final groupEnd = newer == null || !sameRun(m, newer);
          final selected = _selected.contains(m.id);
          final highlighted =
              _highlightId == m.id || (_searching && _matchId == m.id);
          return Column(
            key: _itemKeys.putIfAbsent(m.id, GlobalKey.new),
            children: [
              if (showDay)
                _DaySeparator(
                  DateFormatter.daySeparator(
                    m.createdAt,
                    locale,
                    today: l.today,
                    yesterday: l.yesterday,
                  ),
                ),
              _FadeIn(
                key: ValueKey(m.id),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _selecting ? () => _toggle(m.id) : null,
                  onLongPress: () {
                    HapticFeedback.selectionClick();
                    _toggle(m.id);
                  },
                  child: Semantics(
                    selected: selected,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      color:
                          selected
                              ? c.primary.withValues(alpha: 0.18)
                              : highlighted
                              ? c.accent.withValues(alpha: 0.24)
                              : Colors.transparent,
                      child: AbsorbPointer(
                        absorbing: _selecting,
                        child:
                            state.editing?.id == m.id
                                ? InlineEditBubble(
                                  initialText: m.text ?? '',
                                  onSave: vm.saveEdit,
                                  onCancel: vm.cancelEdit,
                                )
                                : MessageBubble(
                                  conversationId: _cid,
                                  message: m,
                                  mine: mine,
                                  myUid: me,
                                  status: mine ? statusOf(m) : null,
                                  isGroupStart: groupStart,
                                  isGroupEnd: groupEnd,
                                  senderName:
                                      isGroup && !mine && groupStart
                                          ? (ref
                                                  .watch(
                                                    profileByUidProvider(
                                                      m.senderId,
                                                    ),
                                                  )
                                                  .value
                                                  ?.displayName ??
                                              '…')
                                          : null,
                                  avatarSlot:
                                      isGroup && !mine
                                          ? (groupEnd
                                              ? Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 8,
                                                  bottom: 2,
                                                ),
                                                child: _MiniAvatar(
                                                  uid: m.senderId,
                                                ),
                                              )
                                              : const SizedBox.shrink())
                                          : null,
                                  onSwipeReply:
                                      m.deleted ? null : () => vm.setReplyTo(m),
                                  replyTarget:
                                      m.replyToId == null
                                          ? null
                                          : byId[m.replyToId],
                                  onReplyTap:
                                      m.replyToId == null
                                          ? null
                                          : () =>
                                              _scrollToMessage(m.replyToId!),
                                  onReactionTap:
                                      m.deleted
                                          ? null
                                          : (emoji) => _toggleReactionFor(
                                            m.id,
                                            emoji,
                                            me,
                                          ),
                                  onImageTap:
                                      m.mediaPath == null || m.deleted
                                          ? null
                                          : () => context.push(
                                            '/image',
                                            extra: {
                                              'path': m.mediaPath,
                                              'thumb': m.thumbnailPath,
                                            },
                                          ),
                                ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    Widget composer;
    if (removedFromGroup) {
      composer = _Notice(text: l.notInGroup);
    } else if (deleted) {
      composer = _Notice(text: l.accountDeletedNotice);
    } else if (iBlocked) {
      composer = _Notice(
        text: l.youBlocked,
        actionLabel: l.unblock,
        onAction:
            () => ref.read(safetyRepositoryProvider).unblock(me, otherUid),
      );
    } else {
      composer = Composer(
        onSend: vm.sendText,
        onChanged: vm.typingChanged,
        onAttach: _attach,
        conversationId: _cid,
        onVoice: vm.sendVoice,
        replyTo: state.replyTo,
        onCancelReply: () => vm.setReplyTo(null),
      );
    }

    final singleSelected = _selected.length == 1 ? byId[_selected.first] : null;

    return PopScope(
      canPop: !_selecting && !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_selecting) {
          _clearSelection();
        } else if (_searching) {
          _closeSearch();
        }
      },
      child: Scaffold(
        backgroundColor: c.chatBackground,
        appBar:
            _selecting
                ? _selectionBar(state, me)
                : _searching
                ? _searchBar()
                : AppBar(
                  leading: const HushloBackButton(),
                  leadingWidth: 60,
                  titleSpacing: 0,
                  backgroundColor: c.surface,
                  title: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap:
                        deleted
                            ? null
                            : () => context.push(
                              isGroup
                                  ? '/chat/$_cid/group'
                                  : '/chat/$_cid/info',
                            ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 4,
                      ),
                      child: Row(
                        children: [
                          Hero(
                            tag: isGroup ? 'avatar_$_cid' : 'avatar_$otherUid',
                            child: UserAvatar(
                              name: name,
                              group: isGroup,
                              photoPath:
                                  isGroup
                                      ? convValue?.photoPath
                                      : (deleted
                                          ? null
                                          : otherProfile?.photoPath),
                              size: 40,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if ((convValue?.disappearAfterSec ?? 0) > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: Tooltip(
                                          message: l.disappearingTitle,
                                          child: Icon(
                                            Icons.timer_outlined,
                                            size: 16,
                                            color: c.textSecondary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (isGroup && convValue != null)
                                  _GroupSubtitle(
                                    group: convValue,
                                    me: me,
                                    typingUids: groupTypingUids,
                                  )
                                else if (!deleted && otherProfile != null)
                                  Row(
                                    children: [
                                      if (isOnlineNow)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(
                                            right: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: c.success,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      Flexible(
                                        child: Text(
                                          typingNow
                                              ? l.typing
                                              : (presence ?? l.tapForInfo),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.copyWith(
                                            color:
                                                (isOnlineNow || typingNow)
                                                    ? c.success
                                                    : c.textSecondary,
                                            fontWeight:
                                                typingNow
                                                    ? FontWeight.w600
                                                    : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    PopupMenuButton<String>(
                      tooltip: l.moreOptions,
                      offset: const Offset(0, 48),
                      // ignore: sort_child_properties_last
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: c.surfaceSubtle,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.more_horiz_rounded,
                                size: 22,
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onSelected: (v) async {
                        final repo = ref.read(conversationRepositoryProvider);
                        switch (v) {
                          case 'pin':
                            await repo.setPinned(_cid, me, !prefs.pinned);
                          case 'archive':
                            await repo.setArchived(_cid, me, !prefs.archived);
                            if (!prefs.archived && context.mounted) {
                              context.pop();
                            }
                          case 'mute':
                            if (prefs.isMuted()) {
                              await repo.setMutedUntil(_cid, me, null);
                            } else {
                              await _mute(me);
                            }
                          case 'group':
                            if (context.mounted) {
                              context.push('/chat/$_cid/group');
                            }
                          case 'search':
                            _openSearch();
                          case 'theme':
                            await showChatThemeSheet(
                              context,
                              conversationId: _cid,
                              me: me,
                            );
                          case 'clear':
                            await _confirmClear(name);
                          case 'block':
                            await _confirmBlock(otherUid, name);
                          case 'report':
                            if (context.mounted) {
                              await showReportDialog(
                                context,
                                ref,
                                reportedUid: otherUid,
                                conversationId: _cid,
                              );
                            }
                        }
                      },
                      itemBuilder: (_) {
                        PopupMenuItem<String> item(
                          String v,
                          IconData i,
                          String t, {
                          Color? color,
                        }) => PopupMenuItem(
                          value: v,
                          child: Row(
                            children: [
                              Icon(
                                i,
                                size: 20,
                                color: color ?? c.textSecondary,
                              ),
                              const SizedBox(width: 12),
                              Text(t, style: TextStyle(color: color)),
                            ],
                          ),
                        );
                        if (isGroup) {
                          return [
                            item(
                              'group',
                              Icons.info_outline_rounded,
                              l.groupInfo,
                            ),
                            item(
                              'search',
                              Icons.search_rounded,
                              l.searchInChat,
                            ),
                            item(
                              'pin',
                              prefs.pinned
                                  ? Icons.push_pin
                                  : Icons.push_pin_outlined,
                              prefs.pinned ? l.unpin : l.pin,
                            ),
                            item(
                              'mute',
                              prefs.isMuted()
                                  ? Icons.notifications_active_outlined
                                  : Icons.notifications_off_outlined,
                              prefs.isMuted() ? l.unmute : l.mute,
                            ),
                            item(
                              'archive',
                              prefs.archived
                                  ? Icons.unarchive_outlined
                                  : Icons.archive_outlined,
                              prefs.archived ? l.unarchive : l.archive,
                            ),
                            item(
                              'clear',
                              Icons.cleaning_services_outlined,
                              l.clearChat,
                            ),
                          ];
                        }
                        return [
                          item('search', Icons.search_rounded, l.searchInChat),
                          item('theme', Icons.palette_outlined, l.chatTheme),
                          item(
                            'pin',
                            prefs.pinned
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                            prefs.pinned ? l.unpin : l.pin,
                          ),
                          item(
                            'mute',
                            prefs.isMuted()
                                ? Icons.notifications_active_outlined
                                : Icons.notifications_off_outlined,
                            prefs.isMuted() ? l.unmute : l.mute,
                          ),
                          item(
                            'archive',
                            prefs.archived
                                ? Icons.unarchive_outlined
                                : Icons.archive_outlined,
                            prefs.archived ? l.unarchive : l.archive,
                          ),
                          item(
                            'clear',
                            Icons.cleaning_services_outlined,
                            l.clearChat,
                          ),
                          if (!deleted && !iBlocked)
                            item(
                              'block',
                              Icons.block_rounded,
                              l.block,
                              color: c.error,
                            ),
                          if (!deleted)
                            item(
                              'report',
                              Icons.flag_outlined,
                              l.report,
                              color: c.error,
                            ),
                        ];
                      },
                    ),
                  ],
                ),
        body: DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: const AssetImage('assets/illustrations/chat_pattern.png'),
              repeat: ImageRepeat.repeat,
              opacity:
                  Theme.of(context).brightness == Brightness.dark ? 0.35 : 1,
              scale: 2,
            ),
          ),
          child: Column(
            children: [
              if (!online) const OfflineBanner(),
              if (singleSelected != null && !singleSelected.deleted)
                _reactionStrip(singleSelected),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child:
                            _ready
                                ? KeyedSubtree(
                                  key: const ValueKey('chat-body'),
                                  child: RepaintBoundary(child: body),
                                )
                                : const SizedBox.shrink(
                                  key: ValueKey('chat-placeholder'),
                                ),
                      ),
                    ),
                    if (_showNewIndicator)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: FilledButton.icon(
                            onPressed: _jumpToBottom,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              backgroundColor: c.primary,
                              shape: const StadiumBorder(),
                            ),
                            icon: const Icon(
                              Icons.arrow_downward_rounded,
                              size: 18,
                            ),
                            label: Text(l.newMessages),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!_selecting)
                _ready
                    ? composer
                    : SizedBox(
                      height: 76 + MediaQuery.paddingOf(context).bottom,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated three-dot bubble shown while the other person is typing.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      liveRegion: true,
      label: context.l10n.typing,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: c.bubbleIn,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(5),
              ),
              border: Border.all(color: c.outline.withValues(alpha: 0.7)),
            ),
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: EdgeInsets.only(right: i == 2 ? 0 : 5),
                        child: Transform.translate(
                          offset: Offset(
                            0,
                            -3.5 * _wave((_c.value - i * 0.16) % 1.0),
                          ),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c.textSecondary.withValues(
                                alpha:
                                    0.45 +
                                    0.5 * _wave((_c.value - i * 0.16) % 1.0),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// 0..1 bump over the first half of the cycle, then rest.
  double _wave(double t) =>
      t < 0.5 ? (1 - (t * 4 - 1).abs()).clamp(0.0, 1.0) : 0.0;
}

enum _Attach { gallery, camera, video, recordVideo, document }

class _AttachOption extends StatelessWidget {
  const _AttachOption({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.last.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 10),
              ExcludeSemantics(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: c.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.actionLabel, this.onAction});
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (actionLabel != null)
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Short fade + slight rise on first build (message insertion motion).
class _FadeIn extends StatelessWidget {
  const _FadeIn({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      builder:
          (_, v, c) => Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, (1 - v) * 8),
              child: c,
            ),
          ),
      child: child,
    );
  }
}

/// Small avatar next to incoming group messages.
class _MiniAvatar extends ConsumerWidget {
  const _MiniAvatar({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileByUidProvider(uid)).value;
    return UserAvatar(
      name: p?.displayName ?? '?',
      photoPath: p?.photoPath,
      size: 28,
    );
  }
}

/// Header subtitle for groups: "typing…" or the member names.
class _GroupSubtitle extends ConsumerWidget {
  const _GroupSubtitle({
    required this.group,
    required this.me,
    required this.typingUids,
  });

  final Conversation group;
  final String me;
  final List<String> typingUids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.colors;
    String nameOf(String uid) =>
        uid == me
            ? l.you
            : (ref.watch(profileByUidProvider(uid)).value?.displayName ?? '…');

    final String text;
    final bool typing = typingUids.isNotEmpty;
    if (typing) {
      final names = typingUids.take(3).map((u) => nameOf(u).split(' ').first);
      text =
          typingUids.length == 1
              ? l.typingOne(names.first)
              : l.typingMany(names.join(', '));
    } else {
      text = group.memberIds.map(nameOf).join(', ');
    }
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: typing ? c.success : c.textSecondary,
        fontWeight: typing ? FontWeight.w600 : null,
      ),
    );
  }
}
