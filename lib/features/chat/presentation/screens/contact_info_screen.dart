import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/hushlo_back_button.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/firebase/media_url_provider.dart';
import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/theme/hushlo_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/viewmodels/auth_providers.dart';
import '../../../conversations/domain/entities/conversation.dart';
import '../../../conversations/presentation/viewmodels/conversation_providers.dart';
import '../../../profile/presentation/viewmodels/profile_providers.dart';
import '../../../safety/presentation/viewmodels/safety_providers.dart';
import '../../../safety/presentation/widgets/report_dialog.dart';
import '../viewmodels/chat_view_model.dart';

/// Contact info (opened by tapping the name in a chat): photo, name,
/// username, bio, quick actions, shared photos, block & report.
class ContactInfoScreen extends ConsumerWidget {
  const ContactInfoScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final me = ref.watch(currentUidProvider);
    if (me == null) return const SizedBox.shrink();

    final conv = ref.watch(conversationProvider(conversationId)).value;
    final otherUid =
        conv?.otherUid(me) ??
        conversationId.split('_').firstWhere((u) => u != me, orElse: () => '');
    final profile = ref.watch(profileByUidProvider(otherUid)).value;
    final prefs =
        ref.watch(memberPrefsProvider(conversationId)).value ??
        const MemberPrefs();
    final blocked = ref.watch(blockedUidsProvider).value ?? const {};
    final isBlocked = blocked.contains(otherUid);
    final repo = ref.read(conversationRepositoryProvider);
    final name = profile?.displayName ?? l.deletedAccount;

    final photos =
        ref
            .watch(chatViewModelProvider(conversationId))
            .messages
            .where((m) => m.isImage && m.mediaPath != null)
            .toList();

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
          Container(
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
                bottom: Radius.circular(36),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 22),
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
                      onTap:
                          profile?.photoPath == null
                              ? null
                              : () => context.push(
                                '/image',
                                extra: {'path': profile!.photoPath},
                              ),
                      child: Semantics(
                        button: profile?.photoPath != null,
                        label: l.viewPhoto,
                        child: Hero(
                          tag: 'avatar_$otherUid',
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: UserAvatar(
                              name: name,
                              photoPath: profile?.photoPath,
                              size: 92,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Semantics(
                      header: true,
                      child: Text(
                        name,
                        style: t.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (profile != null)
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: '@${profile.username}'),
                          );
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(l.copied)));
                        },
                        icon: const Icon(
                          Icons.alternate_email_rounded,
                          size: 16,
                          color: Colors.white70,
                        ),
                        label: Text(
                          profile.username,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.list(
                    children: [
                      _Section(
                        title: l.about,
                        child: Text(
                          (profile?.bio ?? '').isEmpty
                              ? l.bioEmpty
                              : profile!.bio!,
                          style: t.bodyLarge?.copyWith(
                            color:
                                (profile?.bio ?? '').isEmpty
                                    ? c.textSecondary
                                    : c.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                                  conversationId,
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
                            prefs.pinned
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                            prefs.pinned ? l.unpin : l.pin,
                            prefs.pinned,
                            () => repo
                                .setPinned(conversationId, me, !prefs.pinned)
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
                                .setArchived(
                                  conversationId,
                                  me,
                                  !prefs.archived,
                                )
                                .catchError((Object _) {}),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Section(
                        title: l.sharedPhotos,
                        child:
                            photos.isEmpty
                                ? Text(
                                  l.noSharedPhotos,
                                  style: t.bodyMedium?.copyWith(
                                    color: c.textSecondary,
                                  ),
                                )
                                : GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount:
                                      photos.length > 9 ? 9 : photos.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        mainAxisSpacing: 6,
                                        crossAxisSpacing: 6,
                                      ),
                                  itemBuilder:
                                      (_, i) => _PhotoThumb(
                                        path:
                                            photos[i].thumbnailPath ??
                                            photos[i].mediaPath!,
                                        fullPath: photos[i].mediaPath!,
                                      ),
                                ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(
                                Icons.block_rounded,
                                color: c.error,
                              ),
                              title: Text(
                                isBlocked ? l.unblock : l.blockUser(name),
                                style: TextStyle(color: c.error),
                              ),
                              onTap:
                                  otherUid.isEmpty
                                      ? null
                                      : () async {
                                        final safety = ref.read(
                                          safetyRepositoryProvider,
                                        );
                                        try {
                                          if (isBlocked) {
                                            await safety.unblock(me, otherUid);
                                          } else {
                                            await safety.block(me, otherUid);
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  failureMessage(
                                                    l,
                                                    Failure.from(e),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: Icon(
                                Icons.flag_outlined,
                                color: c.error,
                              ),
                              title: Text(
                                l.report,
                                style: TextStyle(color: c.error),
                              ),
                              onTap:
                                  otherUid.isEmpty
                                      ? null
                                      : () => showReportDialog(
                                        context,
                                        ref,
                                        reportedUid: otherUid,
                                        conversationId: conversationId,
                                      ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: c.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _PhotoThumb extends ConsumerWidget {
  const _PhotoThumb({required this.path, required this.fullPath});
  final String path;
  final String fullPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final url = ref.watch(mediaUrlProvider(path));
    return Semantics(
      button: true,
      label: context.l10n.photo,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/image', extra: {'path': fullPath}),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: url.when(
            data:
                (u) => CachedNetworkImage(
                  imageUrl: u,
                  cacheKey: path,
                  fit: BoxFit.cover,
                  memCacheWidth: 300,
                  placeholder: (_, __) => Container(color: c.surfaceSubtle),
                  errorWidget:
                      (_, __, ___) => Container(
                        color: c.surfaceSubtle,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                ),
            loading: () => Container(color: c.surfaceSubtle),
            error:
                (_, __) => Container(
                  color: c.surfaceSubtle,
                  child: const Icon(Icons.broken_image_outlined),
                ),
          ),
        ),
      ),
    );
  }
}
