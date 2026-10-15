import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/theme/hushlo_colors.dart';
import '../../../../core/widgets/hushlo_back_button.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../attachments/presentation/viewmodels/attachment_providers.dart';
import '../../../auth/presentation/viewmodels/auth_providers.dart';
import '../../../conversations/domain/entities/conversation.dart';
import '../../../conversations/presentation/viewmodels/conversation_providers.dart';
import '../../../chat_theme/presentation/chat_theme_tile.dart';
import '../../../conversations/presentation/widgets/disappearing_tile.dart';
import '../../../profile/presentation/viewmodels/profile_providers.dart';
import '../../domain/group_rules.dart';
import '../viewmodels/group_providers.dart';

/// Group info: members & admin tools, invite code, join requests, quick
/// actions, clear chat and leave. The header stays pinned.
class GroupInfoScreen extends ConsumerStatefulWidget {
  const GroupInfoScreen({super.key, required this.groupId});
  final String groupId;

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  String get _gid => widget.groupId;

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _run(Future<void> Function() action) async {
    final l = context.l10n;
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      final f = Failure.from(e);
      _toast(
        f is ValidationFailure ? l.cannotRemoveLastAdmin : failureMessage(l, f),
      );
    }
  }

  Future<void> _rename(Conversation g, String me) async {
    final l = context.l10n;
    final ctrl = TextEditingController(text: g.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l.editGroupName),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              maxLength: GroupRules.maxNameLength,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l.groupName),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                child: Text(l.save),
              ),
            ],
          ),
    );
    ctrl.dispose();
    if (name == null ||
        !GroupRules.isValidName(name) ||
        name.trim() == g.name) {
      return;
    }
    await _run(
      () => ref
          .read(groupRepositoryProvider)
          .rename(groupId: _gid, actor: me, name: name),
    );
  }

  Future<void> _changePhoto() async {
    final x = await ref
        .read(imagePickerProvider)
        .pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (x == null) return;
    await _run(() async {
      final processed = await ref
          .read(imageProcessorProvider)
          .processAvatar(File(x.path));
      await ref
          .read(groupRepositoryProvider)
          .setPhoto(groupId: _gid, photo: processed);
    });
  }

  Future<void> _leave(Conversation g, String me) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l.leaveGroupTitle),
            content: Text(l.leaveGroupBody(g.name ?? '')),
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
                child: Text(l.leaveGroup),
              ),
            ],
          ),
    );
    if (ok != true) return;
    await _run(() async {
      await ref.read(groupRepositoryProvider).leave(groupId: _gid, me: me);
      if (mounted) context.go('/chats');
    });
  }

  Future<void> _confirmRemove(String uid, String name, String me) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l.removeMemberTitle(name)),
            content: Text(l.removeMemberBody),
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
                child: Text(l.removeFromGroup),
              ),
            ],
          ),
    );
    if (ok != true) return;
    await _run(
      () => ref
          .read(groupRepositoryProvider)
          .removeMember(groupId: _gid, actor: me, uid: uid),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final me = ref.watch(currentUidProvider);
    final g = ref.watch(conversationProvider(_gid)).value;
    if (me == null || g == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const HushloBackButton(),
          leadingWidth: 60,
          title: Text(l.groupInfo),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final isAdmin = g.isAdmin(me);
    final prefs =
        ref.watch(memberPrefsProvider(_gid)).value ?? const MemberPrefs();
    final repo = ref.read(conversationRepositoryProvider);
    final name = g.name ?? '';

    Widget action(
      IconData icon,
      String label,
      bool active,
      VoidCallback onTap,
    ) => Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: active ? c.primaryContainer : c.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: active ? c.primary : c.outline),
            ),
            child: Column(
              children: [
                Icon(icon, color: active ? c.primary : c.textSecondary),
                const SizedBox(height: 6),
                ExcludeSemantics(
                  child: Text(
                    label,
                    style: t.bodySmall?.copyWith(
                      color: active ? c.primary : c.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      body: Column(
        children: [
          // ---- pinned header ----
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  c.bubbleOut,
                  c.bubbleOutEnd,
                  c.accent.withValues(alpha: 0.9),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(32),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: HushloBackButton(
                          onDark: true,
                          onPressed: () => context.pop(),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: isAdmin ? _changePhoto : null,
                      child: Semantics(
                        button: isAdmin,
                        label: l.changeGroupPhoto,
                        child: Stack(
                          children: [
                            Hero(
                              tag: 'avatar_${g.id}',
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: UserAvatar(
                                  name: name,
                                  photoPath: g.photoPath,
                                  size: 88,
                                  group: true,
                                ),
                              ),
                            ),
                            if (isAdmin)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: CircleAvatar(
                                  radius: 15,
                                  backgroundColor: c.primary,
                                  child: Icon(
                                    Icons.camera_alt_rounded,
                                    size: 15,
                                    color: c.onPrimary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: isAdmin ? () => _rename(g, me) : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (isAdmin) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.edit_rounded,
                                size: 18,
                                color: Colors.white70,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Text(
                      l.membersCount(g.memberIds.length),
                      style: t.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ---- scrollable body ----
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                Row(
                  children: [
                    action(
                      prefs.isMuted()
                          ? Icons.notifications_off_rounded
                          : Icons.notifications_none_rounded,
                      prefs.isMuted() ? l.unmute : l.mute,
                      prefs.isMuted(),
                      () => repo
                          .setMutedUntil(
                            _gid,
                            me,
                            prefs.isMuted()
                                ? null
                                : DateTime.now().add(
                                  const Duration(days: 36500),
                                ),
                          )
                          .catchError((Object _) {}),
                    ),
                    const SizedBox(width: 10),
                    action(
                      prefs.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                      prefs.pinned ? l.unpin : l.pin,
                      prefs.pinned,
                      () => repo
                          .setPinned(_gid, me, !prefs.pinned)
                          .catchError((Object _) {}),
                    ),
                    const SizedBox(width: 10),
                    action(
                      prefs.archived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                      prefs.archived ? l.unarchive : l.archive,
                      prefs.archived,
                      () => repo
                          .setArchived(_gid, me, !prefs.archived)
                          .catchError((Object _) {}),
                    ),
                  ],
                ),
                if (isAdmin) ...[
                  const SizedBox(height: 14),
                  _InviteCard(group: g, me: me, onError: _run),
                  _JoinRequestsCard(group: g, me: me, onError: _run),
                ],
                const SizedBox(height: 14),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          '${l.groupMembersTitle} · ${g.memberIds.length}/$maxGroupMembers',
                          style: t.titleSmall?.copyWith(
                            color: c.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isAdmin && g.memberIds.length < maxGroupMembers)
                        ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: c.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person_add_alt_1_rounded,
                              color: c.onPrimary,
                              size: 22,
                            ),
                          ),
                          title: Text(l.addMembers),
                          onTap: () => context.push('/chat/$_gid/add'),
                        ),
                      for (final uid in g.memberIds)
                        _MemberTile(
                          group: g,
                          uid: uid,
                          me: me,
                          viewerIsAdmin: isAdmin,
                          onMakeAdmin:
                              () => _run(
                                () => ref
                                    .read(groupRepositoryProvider)
                                    .setAdmin(
                                      groupId: _gid,
                                      uid: uid,
                                      admin: true,
                                    ),
                              ),
                          onRemoveAdmin:
                              () => _run(
                                () => ref
                                    .read(groupRepositoryProvider)
                                    .setAdmin(
                                      groupId: _gid,
                                      uid: uid,
                                      admin: false,
                                    ),
                              ),
                          onRemove: (n) => _confirmRemove(uid, n, me),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Column(
                    children: [
                      ChatThemeTile(conversationId: _gid, me: me),
                      const Divider(height: 1),
                      DisappearingTile(
                        conversationId: _gid,
                        me: me,
                        canChange: isAdmin,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.cleaning_services_outlined,
                          color: c.error,
                        ),
                        title: Text(
                          l.clearChat,
                          style: TextStyle(color: c.error),
                        ),
                        onTap: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder:
                                (ctx) => AlertDialog(
                                  title: Text(l.clearChatTitle),
                                  content: Text(l.clearChatBody(name)),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(ctx, false),
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
                          if (ok == true) {
                            await _run(() => repo.clearChat(_gid, me));
                            if (mounted) _toast(l.chatCleared);
                          }
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.logout_rounded, color: c.error),
                        title: Text(
                          l.leaveGroup,
                          style: TextStyle(color: c.error),
                        ),
                        onTap: () => _leave(g, me),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({
    required this.group,
    required this.uid,
    required this.me,
    required this.viewerIsAdmin,
    required this.onMakeAdmin,
    required this.onRemoveAdmin,
    required this.onRemove,
  });

  final Conversation group;
  final String uid;
  final String me;
  final bool viewerIsAdmin;
  final VoidCallback onMakeAdmin;
  final VoidCallback onRemoveAdmin;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.colors;
    final isMe = uid == me;
    final p = ref.watch(profileByUidProvider(uid)).value;
    final deleted = group.deletedAccounts.contains(uid);
    final name = deleted ? l.deletedAccount : (p?.displayName ?? '…');
    final admin = group.isAdmin(uid);

    return ListTile(
      leading: UserAvatar(name: name, photoPath: p?.photoPath, size: 44),
      title: Text(isMe ? '$name (${l.you})' : name),
      subtitle: p == null ? null : Text('@${p.username}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (admin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: c.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                l.admin,
                style: TextStyle(
                  color: c.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          if (viewerIsAdmin && !isMe)
            PopupMenuButton<String>(
              tooltip: l.moreOptions,
              icon: Icon(Icons.more_horiz_rounded, color: c.textSecondary),
              onSelected: (v) {
                switch (v) {
                  case 'admin':
                    onMakeAdmin();
                  case 'unadmin':
                    onRemoveAdmin();
                  case 'remove':
                    onRemove(name);
                }
              },
              itemBuilder:
                  (_) => [
                    PopupMenuItem(
                      value: admin ? 'unadmin' : 'admin',
                      child: Text(admin ? l.removeAdmin : l.makeAdmin),
                    ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Text(
                        l.removeFromGroup,
                        style: TextStyle(color: c.error),
                      ),
                    ),
                  ],
            ),
        ],
      ),
    );
  }
}

class _InviteCard extends ConsumerWidget {
  const _InviteCard({
    required this.group,
    required this.me,
    required this.onError,
  });

  final Conversation group;
  final String me;
  final Future<void> Function(Future<void> Function()) onError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final invite = ref.watch(myInviteProvider(group.id)).value;
    final repo = ref.read(groupRepositoryProvider);

    Future<void> create() => onError(
      () async => repo.createInvite(
        groupId: group.id,
        me: me,
        groupName: group.name ?? '',
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.vpn_key_outlined, color: c.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  l.inviteCode,
                  style: t.titleSmall?.copyWith(
                    color: c.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l.inviteCodeHelp, style: t.bodySmall),
            const SizedBox(height: 12),
            if (invite == null)
              FilledButton.tonal(
                onPressed: create,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(l.createInviteCode),
              )
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: c.surfaceSubtle,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SelectableText(
                  invite.code,
                  textAlign: TextAlign.center,
                  style: t.titleLarge?.copyWith(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: invite.code));
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(l.codeCopied)));
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 46),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: Text(l.copyCode),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          () => SharePlus.instance.share(
                            ShareParams(
                              text: l.inviteShareText(
                                group.name ?? '',
                                invite.code,
                              ),
                            ),
                          ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 46),
                      ),
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: Text(l.shareCode),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(onPressed: create, child: Text(l.resetInviteCode)),
                  TextButton(
                    onPressed:
                        () => onError(() => repo.revokeInvite(invite.code)),
                    style: TextButton.styleFrom(foregroundColor: c.error),
                    child: Text(l.turnOffInvite),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _JoinRequestsCard extends ConsumerWidget {
  const _JoinRequestsCard({
    required this.group,
    required this.me,
    required this.onError,
  });

  final Conversation group;
  final String me;
  final Future<void> Function(Future<void> Function()) onError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final requests = ref.watch(joinRequestsProvider(group.id)).value;
    if (requests == null || requests.isEmpty) return const SizedBox.shrink();
    final repo = ref.read(groupRepositoryProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.how_to_reg_outlined, color: c.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${l.joinRequests} · ${l.requestsPending(requests.length)}',
                    style: t.titleSmall?.copyWith(
                      color: c.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final r in requests)
                Consumer(
                  builder: (context, ref, _) {
                    final p = ref.watch(profileByUidProvider(r.uid)).value;
                    final name = p?.displayName ?? '…';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: UserAvatar(
                        name: name,
                        photoPath: p?.photoPath,
                        size: 42,
                      ),
                      title: Text(name),
                      subtitle: p == null ? null : Text('@${p.username}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: l.reject,
                            onPressed:
                                () => onError(
                                  () => repo.rejectJoin(
                                    groupId: group.id,
                                    uid: r.uid,
                                  ),
                                ),
                            icon: Icon(Icons.close_rounded, color: c.error),
                          ),
                          IconButton.filled(
                            tooltip: l.approve,
                            onPressed:
                                () => onError(
                                  () => repo.approveJoin(
                                    groupId: group.id,
                                    actor: me,
                                    uid: r.uid,
                                  ),
                                ),
                            icon: const Icon(Icons.check_rounded),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
