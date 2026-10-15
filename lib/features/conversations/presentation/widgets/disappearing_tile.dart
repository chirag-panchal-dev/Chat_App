import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/theme/hushlo_colors.dart';
import '../../domain/entities/conversation.dart';
import '../viewmodels/conversation_providers.dart';

/// "24 hours", "7 days", … for a timer value in seconds.
String disappearLabel(AppL10n l, int seconds) => switch (seconds) {
  86400 => l.disappear24h,
  604800 => l.disappear7d,
  7776000 => l.disappear90d,
  _ => l.disappearOff,
};

/// Row in the contact / group info screens that shows and changes the chat's
/// disappearing-messages timer. [canChange] is false for non-admins in groups.
class DisappearingTile extends ConsumerWidget {
  const DisappearingTile({
    super.key,
    required this.conversationId,
    required this.me,
    this.canChange = true,
  });

  final String conversationId;
  final String me;
  final bool canChange;

  Future<void> _pick(BuildContext context, WidgetRef ref, int current) async {
    final l = context.l10n;
    final chosen = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder:
          (ctx) => SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                    child: Text(
                      l.disappearingTitle,
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      l.disappearHint,
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: ctx.colors.textSecondary,
                      ),
                    ),
                  ),
                  for (final s in disappearOptions)
                    RadioListTile<int>(
                      value: s,
                      groupValue: current,
                      onChanged: (v) => Navigator.pop(ctx, v),
                      title: Text(disappearLabel(l, s)),
                    ),
                ],
              ),
            ),
          ),
    );
    if (chosen == null || chosen == current) return;
    try {
      await ref
          .read(conversationRepositoryProvider)
          .setDisappearAfter(conversationId, me, chosen);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.disappearFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.colors;
    final current =
        ref
            .watch(conversationProvider(conversationId))
            .value
            ?.disappearAfterSec ??
        0;
    return ListTile(
      leading: Icon(Icons.timer_outlined, color: c.primary),
      title: Text(l.disappearingTitle),
      subtitle: Text(
        canChange
            ? disappearLabel(l, current)
            : '${disappearLabel(l, current)} · ${l.disappearAdminsOnly}',
      ),
      trailing: canChange ? const Icon(Icons.chevron_right_rounded) : null,
      onTap: canChange ? () => _pick(context, ref, current) : null,
    );
  }
}
