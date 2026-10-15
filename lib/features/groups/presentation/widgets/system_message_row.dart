import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/theme/hushlo_colors.dart';
import '../../../chat/domain/entities/chat_message.dart';
import '../../../conversations/presentation/widgets/disappearing_tile.dart';
import '../../../profile/presentation/viewmodels/profile_providers.dart';

/// Centred notice for group events ("Aarav added Meera", "You left", …).
class SystemMessageRow extends ConsumerWidget {
  const SystemMessageRow({super.key, required this.message, required this.me});
  final ChatMessage message;
  final String me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.colors;

    String nameOf(String uid, {required bool lower}) {
      if (uid == me) return lower ? l.youLower : l.you;
      final p = ref.watch(profileByUidProvider(uid)).value;
      return p?.displayName ?? l.deletedAccount;
    }

    final actor = nameOf(message.senderId, lower: false);
    final target = nameOf(message.targetUid ?? '', lower: true);
    final text = switch (message.event) {
      GroupEvent.added => l.sysAdded(actor, target),
      GroupEvent.removed => l.sysRemoved(actor, target),
      GroupEvent.left => l.sysLeft(
        target.isEmpty
            ? actor
            : nameOf(message.targetUid ?? message.senderId, lower: false),
      ),
      GroupEvent.renamed => l.sysRenamed(actor),
      GroupEvent.timer =>
        (message.timerSec ?? 0) > 0
            ? l.sysTimerOn(actor, disappearLabel(l, message.timerSec!))
            : l.sysTimerOff(actor),
      null => l.groupUpdated,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Center(
        child: Semantics(
          label: text,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: c.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ),
    );
  }
}
