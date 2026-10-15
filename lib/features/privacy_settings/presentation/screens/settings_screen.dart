import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/hushlo_back_button.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/theme/hushlo_colors.dart';
import '../../../../core/utils/app_settings.dart';
import '../../../../core/widgets/confirm_sign_out.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../app_lock/domain/app_lock_models.dart';
import '../../../app_lock/presentation/app_lock_controller.dart';
import '../../../auth/presentation/viewmodels/auth_providers.dart';
import '../../../notifications/presentation/push_controller.dart';
import '../../../profile/presentation/viewmodels/profile_providers.dart';
import '../../domain/privacy_settings.dart';
import '../../domain/quiet_hours.dart';
import '../viewmodels/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final profile = ref.watch(currentProfileProvider).value;
    final settings = ref.watch(settingsProvider).value;
    final push = ref.watch(pushControllerProvider);
    final uid = ref.watch(currentUidProvider);
    final repo = ref.read(settingsRepositoryProvider);

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
                  c.accent.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(32),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
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
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => context.push('/settings/profile'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: UserAvatar(
                                name: profile?.displayName ?? '',
                                photoPath: profile?.photoPath,
                                size: 72,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile?.displayName ?? '',
                                    style: t.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '@${profile?.username ?? ''}',
                                    style: t.bodyMedium?.copyWith(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  if ((profile?.bio ?? '').isNotEmpty)
                                    Text(
                                      profile!.bio!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: t.bodySmall?.copyWith(
                                        color: Colors.white70,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.edit_rounded,
                              color: Colors.white70,
                              size: 20,
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
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  sliver: SliverList.list(
                    children: [
                      _Group(
                        title: l.notifications,
                        children: [
                          _SwitchTile(
                            icon: Icons.notifications_active_rounded,
                            color: const Color(0xFFEF8A3C),
                            title: l.notificationsOn,
                            subtitle: push.denied ? l.notifDeniedHelp : null,
                            value:
                                (settings?.notificationEnabled ?? true) &&
                                push.granted,
                            onChanged:
                                uid == null
                                    ? null
                                    : (v) async {
                                      if (v && !push.granted) {
                                        if (push.denied) {
                                          await ref.read(
                                            openAppSettingsProvider,
                                          )();
                                          return;
                                        }
                                        await ref
                                            .read(
                                              pushControllerProvider.notifier,
                                            )
                                            .requestPermission();
                                      }
                                      await repo.setNotificationEnabled(uid, v);
                                      final ctl = ref.read(
                                        pushControllerProvider.notifier,
                                      );
                                      if (v) {
                                        await ctl.reRegister();
                                      } else {
                                        await ctl.unregister();
                                      }
                                    },
                          ),
                          if (push.status == AuthorizationStatus.denied)
                            _NavTile(
                              icon: Icons.settings_rounded,
                              color: const Color(0xFF7C8A94),
                              title: l.openSettings,
                              onTap: () => ref.read(openAppSettingsProvider)(),
                            ),
                          _SwitchTile(
                            icon: Icons.visibility_rounded,
                            color: const Color(0xFF6E63E8),
                            title: l.showPreviews,
                            subtitle: l.showPreviewsHelp,
                            value: settings?.showMessagePreview ?? false,
                            onChanged:
                                uid == null
                                    ? null
                                    : (v) => repo.setShowMessagePreview(uid, v),
                          ),
                          _SwitchTile(
                            icon: Icons.bedtime_rounded,
                            color: const Color(0xFF5B6BC0),
                            title: l.quietHours,
                            subtitle: l.quietHoursHelp,
                            value: (settings?.quietHours.enabled ?? false),
                            onChanged:
                                uid == null
                                    ? null
                                    : (v) => _saveQuiet(
                                      repo,
                                      uid,
                                      (settings?.quietHours ??
                                              const QuietHours())
                                          .copyWith(enabled: v),
                                    ),
                          ),
                          if (settings?.quietHours.enabled ?? false) ...[
                            _NavTile(
                              icon: Icons.nightlight_round,
                              color: const Color(0xFF5B6BC0),
                              title: l.quietFrom,
                              subtitle: _fmtMinutes(
                                context,
                                settings!.quietHours.startMin,
                              ),
                              onTap:
                                  uid == null
                                      ? () {}
                                      : () => _pickQuiet(
                                        context,
                                        repo,
                                        uid,
                                        settings.quietHours,
                                        start: true,
                                      ),
                            ),
                            _NavTile(
                              icon: Icons.wb_sunny_rounded,
                              color: const Color(0xFFEF8A3C),
                              title: l.quietUntil,
                              subtitle: _fmtMinutes(
                                context,
                                settings.quietHours.endMin,
                              ),
                              onTap:
                                  uid == null
                                      ? () {}
                                      : () => _pickQuiet(
                                        context,
                                        repo,
                                        uid,
                                        settings.quietHours,
                                        start: false,
                                      ),
                            ),
                          ],
                        ],
                      ),
                      const _AppLockGroup(),
                      _Group(
                        title: l.privacyAndSafety,
                        children: [
                          _SwitchTile(
                            icon: Icons.done_all_rounded,
                            color: const Color(0xFF1E9BC4),
                            title: l.readReceipts,
                            subtitle: l.readReceiptsHelp,
                            value: settings?.readReceiptsEnabled ?? true,
                            onChanged:
                                uid == null
                                    ? null
                                    : (v) => repo.setReadReceipts(uid, v),
                          ),
                          _SwitchTile(
                            icon: Icons.access_time_filled_rounded,
                            color: const Color(0xFF2FB38F),
                            title: l.showLastSeen,
                            subtitle: l.showLastSeenHelp,
                            value: settings?.showLastSeen ?? true,
                            onChanged:
                                uid == null
                                    ? null
                                    : (v) => repo.setShowLastSeen(uid, v),
                          ),
                          _NavTile(
                            icon: Icons.block_rounded,
                            color: const Color(0xFFD9534F),
                            title: l.blockedUsers,
                            onTap: () => context.push('/settings/blocked'),
                          ),
                        ],
                      ),
                      _Group(
                        title: l.appearance,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _IconTile(
                                      icon: Icons.palette_rounded,
                                      color: const Color(0xFF2FB38F),
                                    ),
                                    const SizedBox(width: 14),
                                    Text(
                                      l.theme,
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: SegmentedButton<ThemeMode>(
                                    showSelectedIcon: false,
                                    style: SegmentedButton.styleFrom(
                                      textStyle: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      side: BorderSide(color: c.outline),
                                      selectedBackgroundColor: c.primary,
                                      selectedForegroundColor: c.onPrimary,
                                      minimumSize: const Size.fromHeight(44),
                                    ),
                                    segments: [
                                      ButtonSegment(
                                        value: ThemeMode.system,
                                        icon: const Icon(
                                          Icons.brightness_auto_rounded,
                                          size: 18,
                                        ),
                                        label: Text(l.themeSystem),
                                      ),
                                      ButtonSegment(
                                        value: ThemeMode.light,
                                        icon: const Icon(
                                          Icons.light_mode_rounded,
                                          size: 18,
                                        ),
                                        label: Text(l.themeLight),
                                      ),
                                      ButtonSegment(
                                        value: ThemeMode.dark,
                                        icon: const Icon(
                                          Icons.dark_mode_rounded,
                                          size: 18,
                                        ),
                                        label: Text(l.themeDark),
                                      ),
                                    ],
                                    selected: {
                                      settings?.themeMode ?? ThemeMode.system,
                                    },
                                    onSelectionChanged:
                                        uid == null
                                            ? null
                                            : (s) =>
                                                repo.setThemeMode(uid, s.first),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _NavTile(
                            icon: Icons.image_rounded,
                            color: const Color(0xFF7C8A94),
                            title: l.clearImageCache,
                            onTap: () async {
                              await DefaultCacheManager().emptyCache();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(l.cacheCleared)),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      _Group(
                        title: l.about,
                        children: [
                          _NavTile(
                            icon: Icons.privacy_tip_rounded,
                            color: const Color(0xFF1E8FA8),
                            title: l.privacyPolicy,
                            onTap: () => context.push('/legal/privacy'),
                          ),
                          _NavTile(
                            icon: Icons.description_rounded,
                            color: const Color(0xFF5B4FE0),
                            title: l.terms,
                            onTap: () => context.push('/legal/terms'),
                          ),
                          _NavTile(
                            icon: Icons.groups_rounded,
                            color: const Color(0xFF2FB38F),
                            title: l.communityGuidelines,
                            onTap: () => context.push('/legal/community'),
                          ),
                          if (AppConfig.supportEmail.isNotEmpty)
                            _NavTile(
                              icon: Icons.mail_rounded,
                              color: const Color(0xFFEF8A3C),
                              title: l.support,
                              subtitle: AppConfig.supportEmail,
                              onTap:
                                  () => launchUrl(
                                    Uri(
                                      scheme: 'mailto',
                                      path: AppConfig.supportEmail,
                                    ),
                                  ),
                            ),
                        ],
                      ),
                      _Group(
                        title: l.account,
                        children: [
                          _NavTile(
                            icon: Icons.logout_rounded,
                            color: const Color(0xFF7C8A94),
                            title: l.signOut,
                            onTap: () async {
                              if (!await confirmSignOut(context)) return;
                              await ref
                                  .read(pushControllerProvider.notifier)
                                  .unregister();
                              await ref.read(authRepositoryProvider).signOut();
                            },
                          ),
                          _NavTile(
                            icon: Icons.delete_forever_rounded,
                            color: c.error,
                            title: l.deleteAccount,
                            destructive: true,
                            onTap:
                                () => context.push('/settings/delete-account'),
                          ),
                        ],
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

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Semantics(
              header: true,
              child: Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: c.textSecondary,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 64),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(icon, color: Colors.white, size: 20),
  );
}

String _fmtMinutes(BuildContext context, int minutes) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

/// Saves the window together with the phone's current UTC offset (the server
/// uses it to work out the user's local time).
Future<void> _saveQuiet(SettingsRepository repo, String uid, QuietHours q) =>
    repo.setQuietHours(
      uid,
      q,
      utcOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
    );

Future<void> _pickQuiet(
  BuildContext context,
  SettingsRepository repo,
  String uid,
  QuietHours q, {
  required bool start,
}) async {
  final current = start ? q.startMin : q.endMin;
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
  );
  if (picked == null) return;
  final m = picked.hour * 60 + picked.minute;
  await _saveQuiet(
    repo,
    uid,
    start ? q.copyWith(startMin: m) : q.copyWith(endMin: m),
  );
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListTile(
      minTileHeight: 56,
      leading: _IconTile(icon: icon, color: color),
      title: Text(title, style: TextStyle(color: destructive ? c.error : null)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing:
          destructive
              ? null
              : Icon(Icons.chevron_right_rounded, color: c.textSecondary),
      onTap: onTap,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    secondary: _IconTile(icon: icon, color: color),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    value: value,
    onChanged: onChanged,
  );
}

/// App lock: Face ID / fingerprint / passcode, lock delay and app-switcher cover.
/// Device-local; changing it requires authenticating first.
class _AppLockGroup extends ConsumerWidget {
  const _AppLockGroup();

  String _timeoutLabel(AppL10n l, AppLockTimeout t) => switch (t) {
    AppLockTimeout.immediately => l.timeoutImmediately,
    AppLockTimeout.oneMinute => l.timeout1m,
    AppLockTimeout.fiveMinutes => l.timeout5m,
    AppLockTimeout.fifteenMinutes => l.timeout15m,
    AppLockTimeout.oneHour => l.timeout1h,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final available = ref.watch(appLockAvailableProvider).value ?? true;
    final s = ref.watch(appLockProvider).settings;
    final ctl = ref.read(appLockProvider.notifier);

    return _Group(
      title: l.appLock,
      children: [
        _SwitchTile(
          icon: Icons.fingerprint_rounded,
          color: const Color(0xFF1E8FA8),
          title: l.appLock,
          subtitle: available || s.enabled ? l.appLockHelp : l.lockNotAvailable,
          value: s.enabled,
          onChanged:
              (!available && !s.enabled)
                  ? null
                  : (v) async {
                    final r = await ctl.setEnabled(
                      v,
                      reason: l.changeLockReason,
                    );
                    if (!context.mounted || r == LockChange.done) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          r == LockChange.notAvailable
                              ? l.lockNotAvailable
                              : l.lockVerifyFailed,
                        ),
                      ),
                    );
                  },
        ),
        if (s.enabled)
          _NavTile(
            icon: Icons.timer_outlined,
            color: const Color(0xFF5B4FE0),
            title: l.lockAfter,
            subtitle: _timeoutLabel(l, s.timeout),
            onTap:
                () => showModalBottomSheet<void>(
                  context: context,
                  builder:
                      (ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final t in AppLockTimeout.values)
                              ListTile(
                                title: Text(_timeoutLabel(l, t)),
                                trailing:
                                    t == s.timeout
                                        ? Icon(
                                          Icons.check_rounded,
                                          color: ctx.colors.primary,
                                        )
                                        : null,
                                onTap: () {
                                  Navigator.pop(ctx);
                                  ctl.setTimeout(t);
                                },
                              ),
                          ],
                        ),
                      ),
                ),
          ),
        if (s.enabled)
          _SwitchTile(
            icon: Icons.visibility_off_rounded,
            color: const Color(0xFF7C8A94),
            title: l.hideAppPreview,
            subtitle: l.hideAppPreviewHelp,
            value: s.hidePreview,
            onChanged: ctl.setHidePreview,
          ),
      ],
    );
  }
}
