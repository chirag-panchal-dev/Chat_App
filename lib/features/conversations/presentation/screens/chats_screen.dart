import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/theme/hushlo_colors.dart';
import '../../../../core/utils/connectivity.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../chat/domain/entities/chat_message.dart';
import '../../../chat/presentation/viewmodels/chat_providers.dart';
import '../../../chat/presentation/widgets/message_ticks.dart';
import '../../../notifications/presentation/push_controller.dart';
import '../../../privacy_settings/presentation/viewmodels/settings_providers.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../../profile/presentation/viewmodels/profile_providers.dart';
import '../../../voice/domain/voice_models.dart';
import '../../domain/entities/conversation.dart';
import '../viewmodels/conversation_providers.dart';

enum _Filter { all, unread, pinned }

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  bool _showArchived = false;
  _Filter _filter = _Filter.all;
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Consume a notification tap that arrived before we were ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePending());
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// "Start something new": chat, group, or join with a code.
  void _showStartSheet(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    showModalBottomSheet<void>(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l.startSheetTitle,
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  for (final o in [
                    (
                      Icons.chat_bubble_rounded,
                      const [Color(0xFF43CDB8), Color(0xFF1E8FA8)],
                      l.newChat,
                      l.newChatDesc,
                      '/new-chat',
                    ),
                    (
                      Icons.groups_rounded,
                      const [Color(0xFF8C83F6), Color(0xFF5B4FE0)],
                      l.newGroup,
                      l.newGroupDesc(maxGroupMembers),
                      '/new-group',
                    ),
                    (
                      Icons.bookmark_rounded,
                      const [Color(0xFF59C3A6), Color(0xFF2FB38F)],
                      l.savedMessages,
                      l.savedMessagesDesc,
                      '/saved',
                    ),
                    (
                      Icons.vpn_key_rounded,
                      const [Color(0xFFF6B94A), Color(0xFFEF8A3C)],
                      l.joinWithCode,
                      l.joinWithCodeDesc,
                      '/join-group',
                    ),
                  ])
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: o.$2,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Icon(o.$1, color: Colors.white, size: 24),
                      ),
                      title: Text(
                        o.$3,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(o.$4),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: c.textSecondary,
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        context.push(o.$5);
                      },
                    ),
                ],
              ),
            ),
          ),
    );
  }

  void _consumePending() {
    if (!mounted) return;
    final id = ref.read(pendingConversationProvider);
    if (id == null) return;
    ref.read(pendingConversationProvider.notifier).set(null);
    context.push('/chat/$id');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    ref.listen(pendingConversationProvider, (_, id) {
      if (id != null) _consumePending();
    });

    final inbox = ref.watch(inboxProvider);
    final online = ref.watch(isOnlineProvider).value ?? true;
    final profile = ref.watch(currentProfileProvider).value;
    final push = ref.watch(pushControllerProvider);

    return Scaffold(
      floatingActionButton: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [c.bubbleOut, c.bubbleOutEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: c.primary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          tooltip: l.newChat,
          elevation: 0,
          backgroundColor: Colors.transparent,
          focusElevation: 0,
          highlightElevation: 0,
          foregroundColor: Colors.white,
          onPressed: () => _showStartSheet(context),
          child: const Icon(Icons.edit_rounded),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Large-title header (Telegram/iMessage style).
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        _showArchived ? l.archivedChats : l.chats,
                        style: t.headlineMedium?.copyWith(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: l.settings,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => context.push('/settings'),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: c.primary, width: 2),
                        ),
                        child: UserAvatar(
                          name: profile?.displayName ?? '',
                          photoPath: profile?.photoPath,
                          size: 38,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            if (!online) const OfflineBanner(),
            // Search pill
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l.searchChats,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon:
                      _query.text.isEmpty
                          ? null
                          : IconButton(
                            tooltip: l.closeSearch,
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(_query.clear),
                          ),
                  filled: true,
                  fillColor: c.surfaceSubtle,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(color: c.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            if (!_showArchived)
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  children: [
                    for (final (f, label) in [
                      (_Filter.all, l.filterAll),
                      (_Filter.unread, l.filterUnread),
                      (_Filter.pinned, l.filterPinned),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: _filter == f,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _filter = f),
                          selectedColor: c.primaryContainer,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _filter == f ? c.primary : c.textSecondary,
                          ),
                          side: BorderSide(
                            color: _filter == f ? c.primary : c.outline,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (push.canAsk) const _NotificationPrompt(),
            Expanded(
              child: inbox.when(
                loading: () => const SkeletonList(),
                error:
                    (e, _) => ErrorState(
                      error: e,
                      onRetry: () => ref.invalidate(inboxProvider),
                    ),
                data: (data) => _buildList(context, data),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, Inbox data) {
    final l = context.l10n;
    final q = _query.text.trim().toLowerCase();
    var source = _showArchived ? data.archived : data.active;
    if (!_showArchived) {
      source = switch (_filter) {
        _Filter.all => source,
        _Filter.unread => source.where((i) => i.unread).toList(),
        _Filter.pinned => source.where((i) => i.prefs.pinned).toList(),
      };
    }

    if (data.active.isEmpty && data.archived.isEmpty) {
      return EmptyState(
        illustration: 'assets/illustrations/empty_chats.png',
        icon: Icons.chat_bubble_outline_rounded,
        title: l.chatsEmptyTitle,
        message: l.chatsEmptyBody,
        actionLabel: l.startConversation,
        onAction: () => context.push('/new-chat'),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 104),
      children: [
        if (_showArchived)
          ListTile(
            leading: const Icon(Icons.arrow_back_rounded),
            title: Text(l.chats),
            onTap: () => setState(() => _showArchived = false),
          ),
        if (!_showArchived && _filter == _Filter.all && q.isEmpty)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF59C3A6), Color(0xFF2FB38F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.bookmark_rounded, color: Colors.white),
            ),
            title: Text(
              l.savedMessages,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(l.savedMessagesDesc, maxLines: 1),
            onTap: () => context.push('/saved'),
          ),
        if (source.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text(
                _showArchived ? l.noArchived : l.noResults,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        for (var k = 0; k < source.length; k++) ...[
          _ConversationTile(item: source[k], query: q),
          if (k < source.length - 1)
            Divider(
              height: 1,
              indent: 88,
              endIndent: 16,
              color: context.colors.outline.withValues(alpha: 0.6),
            ),
        ],
        if (!_showArchived && data.archived.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: Text(l.archivedCount(data.archived.length)),
            onTap: () => setState(() => _showArchived = true),
          ),
      ],
    );
  }
}

class _NotificationPrompt extends ConsumerWidget {
  const _NotificationPrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: c.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              size: 19,
              color: c.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l.notifPromptBody,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          FilledButton(
            onPressed:
                () =>
                    ref
                        .read(pushControllerProvider.notifier)
                        .requestPermission(),
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, 38),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              textStyle: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              shape: const StadiumBorder(),
            ),
            child: Text(l.turnOn),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.item, required this.query});
  final InboxItem item;
  final String query;

  Future<void> _actions(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final repo = ref.read(conversationRepositoryProvider);
    final id = item.conversation.id;
    final p = item.prefs;
    await showModalBottomSheet<void>(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    p.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                  ),
                  title: Text(p.pinned ? l.unpin : l.pin),
                  onTap: () {
                    Navigator.pop(ctx);
                    repo
                        .setPinned(id, item.me, !p.pinned)
                        .catchError((Object _) {});
                  },
                ),
                ListTile(
                  leading: Icon(
                    p.isMuted()
                        ? Icons.notifications_off
                        : Icons.notifications_off_outlined,
                  ),
                  title: Text(p.isMuted() ? l.unmute : l.mute8h),
                  onTap: () {
                    Navigator.pop(ctx);
                    repo
                        .setMutedUntil(
                          id,
                          item.me,
                          p.isMuted()
                              ? null
                              : DateTime.now().add(const Duration(hours: 8)),
                        )
                        .catchError((Object _) {});
                  },
                ),
                ListTile(
                  leading: Icon(
                    p.archived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                  title: Text(p.archived ? l.unarchive : l.archive),
                  onTap: () {
                    Navigator.pop(ctx);
                    repo
                        .setArchived(id, item.me, !p.archived)
                        .catchError((Object _) {});
                  },
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final conv = item.conversation;
    final isGroup = conv.isGroup;
    final otherUid = isGroup ? '' : conv.otherUid(item.me);
    final AsyncValue<Profile?> profile =
        isGroup
            ? const AsyncData<Profile?>(null)
            : ref.watch(profileByUidProvider(otherUid));
    final deleted =
        !isGroup &&
        (conv.otherDeleted(item.me) ||
            (profile.hasValue && profile.value == null));
    final name =
        isGroup
            ? (conv.name ?? '')
            : (deleted
                ? l.deletedAccount
                : (profile.value?.displayName ?? '…'));

    final cleared = item.isCleared;
    final last = cleared ? null : item.lastMessage;
    final mineDeleted = last != null && last.senderId == item.me;
    // Group rows prefix the sender ("Aarav: hi", "You: hi").
    final senderPrefix =
        (isGroup && last != null && !last.isSystem)
            ? (last.senderId == item.me
                ? '${l.you}: '
                : '${(ref.watch(profileByUidProvider(last.senderId)).value?.displayName ?? '…').split(' ').first}: ')
            : '';
    final basePreview =
        last == null
            ? (conv.lastMessagePreview ?? l.noMessagesYet)
            : last.isSystem
            ? (last.isTimer ? l.timerUpdated : l.groupUpdated)
            : last.deleted
            ? (mineDeleted ? l.youDeletedMessage : l.messageDeleted)
            : last.isVideo
            ? l.video
            : last.isFile
            ? l.document
            : last.isVoice
            ? '${l.voiceMessage}${last.durationMs == null ? '' : ' (${formatVoiceDuration(last.durationMs!)})'}'
            : (last.isImage
                ? (last.preview.isEmpty ? l.photo : last.preview)
                : last.preview);
    final previewText = '$senderPrefix$basePreview';

    if (query.isNotEmpty &&
        !name.toLowerCase().contains(query) &&
        !previewText.toLowerCase().contains(query)) {
      return const SizedBox.shrink();
    }

    final locale = Localizations.localeOf(context).toString();
    final at = item.lastActivity;
    final time = at == null ? '' : DateFormatter.inbox(at, locale);
    final unread = item.unread;

    // Live "typing…" in place of the last message (same privacy switch as the
    // chat screen; the clock is watched only while someone is typing).
    final showTyping =
        !deleted &&
        ref.watch(
          settingsProvider.select((st) => st.value?.showLastSeen ?? false),
        );
    final typingAt =
        (showTyping && !isGroup)
            ? ref
                .watch(peerTypingProvider((cid: conv.id, peer: otherUid)))
                .value
            : null;
    final groupSignals =
        (showTyping && isGroup)
            ? ref.watch(typingUsersProvider(conv.id)).value
            : null;
    final groupTypers = typingUids(
      groupSignals,
      item.me,
      (groupSignals?.isNotEmpty ?? false)
          ? ref.watch(typingClockProvider).value
          : null,
    );
    final typing =
        (typingAt != null &&
            isTypingNow(typingAt, ref.watch(typingClockProvider).value)) ||
        groupTypers.isNotEmpty;
    final typingLabel =
        groupTypers.isEmpty
            ? l.typing
            : (groupTypers.length == 1
                ? l.typingOne(
                  (ref
                              .watch(profileByUidProvider(groupTypers.first))
                              .value
                              ?.displayName ??
                          '…')
                      .split(' ')
                      .first,
                )
                : l.typingMany(
                  groupTypers
                      .take(2)
                      .map(
                        (u) =>
                            (ref
                                        .watch(profileByUidProvider(u))
                                        .value
                                        ?.displayName ??
                                    '…')
                                .split(' ')
                                .first,
                      )
                      .join(', '),
                ));
    final p = item.prefs;
    final mine = item.lastIsMine && last != null;

    // Tick for my own last message (real delivery/read state).
    Widget? tick;
    if (mine) {
      final peerReceipts =
          isGroup
              ? null
              : ref
                  .watch(peerReceiptsProvider((cid: conv.id, peer: otherUid)))
                  .value;
      final groupReceipts =
          isGroup
              ? (ref.watch(groupReceiptsProvider(conv.id)).value ??
                  const <String, Receipts>{})
              : const <String, Receipts>{};
      final receiptsOn =
          ref.watch(settingsProvider).value?.readReceiptsEnabled ?? true;
      final msg = ChatMessage(
        id: '',
        senderId: item.me,
        type: last.isImage ? MessageType.image : MessageType.text,
        createdAt: last.at,
        status: last.pending ? SendStatus.sending : SendStatus.sent,
      );
      var st =
          isGroup
              ? resolveGroupStatus(msg, groupReceipts, conv.othersOf(item.me))
              : resolveStatus(msg, peerReceipts);
      if (!receiptsOn && st == SendStatus.read) st = SendStatus.delivered;
      tick = Padding(
        padding: const EdgeInsets.only(right: 4),
        child: MessageTicks(status: st, baseColor: c.textSecondary, size: 17),
      );
    }

    return Semantics(
      label: [
        name,
        if (unread) l.unread,
        if (p.pinned) l.pinned,
        if (p.isMuted()) l.muted,
        typing ? typingLabel : previewText,
        time,
      ].join(', '),
      child: InkWell(
        onTap: () => context.push('/chat/${conv.id}'),
        onLongPress: () => _actions(context, ref),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 76),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Hero(
                    tag: isGroup ? 'avatar_${conv.id}' : 'avatar_$otherUid',
                    child: UserAvatar(
                      name: name,
                      group: isGroup,
                      photoPath:
                          isGroup
                              ? conv.photoPath
                              : (deleted ? null : profile.value?.photoPath),
                      size: 58,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.titleMedium?.copyWith(
                                  fontWeight:
                                      unread
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              time,
                              style: t.bodySmall?.copyWith(
                                color: unread ? c.primary : c.textSecondary,
                                fontWeight:
                                    unread ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (!typing && tick != null) tick,
                            if (!typing &&
                                last != null &&
                                last.isImage &&
                                !last.deleted)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.photo_camera_outlined,
                                  size: 16,
                                  color: c.textSecondary,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                typing ? typingLabel : previewText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodyMedium?.copyWith(
                                  color:
                                      typing
                                          ? c.success
                                          : unread
                                          ? c.textPrimary
                                          : c.textSecondary,
                                  fontWeight:
                                      typing || unread
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                ),
                              ),
                            ),
                            if (p.isMuted())
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Icon(
                                  Icons.notifications_off_outlined,
                                  size: 16,
                                  color: c.textSecondary,
                                ),
                              ),
                            if (p.pinned)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Icon(
                                  Icons.push_pin_outlined,
                                  size: 16,
                                  color: c.textSecondary,
                                ),
                              ),
                            if (unread)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: c.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: c.primary.withValues(alpha: 0.4),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
