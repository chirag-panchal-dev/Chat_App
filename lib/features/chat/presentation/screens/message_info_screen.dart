import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/theme/hushlo_colors.dart';
import '../../../../core/widgets/hushlo_back_button.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/viewmodels/auth_providers.dart';
import '../../../conversations/presentation/viewmodels/conversation_providers.dart';
import '../../../profile/presentation/viewmodels/profile_providers.dart';
import '../../domain/entities/chat_message.dart';
import '../message_preview.dart';
import '../viewmodels/chat_view_model.dart';

/// Per-person delivery/read status of one of *my* messages in a group.
class MessageInfoScreen extends ConsumerWidget {
  const MessageInfoScreen({
    super.key,
    required this.conversationId,
    required this.messageId,
  });

  final String conversationId;
  final String messageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final me = ref.watch(currentUidProvider);
    final conv = ref.watch(conversationProvider(conversationId)).value;
    final msgs = ref.watch(chatViewModelProvider(conversationId)).messages;
    final receipts =
        ref.watch(groupReceiptsProvider(conversationId)).value ?? const {};
    ChatMessage? m;
    for (final x in msgs) {
      if (x.id == messageId) m = x;
    }

    final others =
        (me == null || conv == null) ? <String>[] : conv.othersOf(me);
    final groups = <SendStatus, List<String>>{
      SendStatus.read: [],
      SendStatus.delivered: [],
      SendStatus.sent: [],
    };
    if (m != null) {
      for (final uid in others) {
        final st = memberStatus(m, receipts[uid]);
        groups[st == SendStatus.read || st == SendStatus.delivered
                ? st
                : SendStatus.sent]!
            .add(uid);
      }
    }

    Widget section(
      String title,
      IconData icon,
      Color color,
      List<String> uids,
    ) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: color),
                    const SizedBox(width: 8),
                    Text(
                      '$title · ${uids.length}',
                      style: t.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (uids.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Text(l.infoNobody, style: t.bodySmall),
                )
              else
                for (final uid in uids)
                  Consumer(
                    builder: (context, ref, _) {
                      final p = ref.watch(profileByUidProvider(uid)).value;
                      final name = p?.displayName ?? '…';
                      return ListTile(
                        dense: true,
                        leading: UserAvatar(
                          name: name,
                          photoPath: p?.photoPath,
                          size: 38,
                        ),
                        title: Text(name),
                        subtitle: p == null ? null : Text('@${p.username}'),
                      );
                    },
                  ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: const HushloBackButton(),
        leadingWidth: 60,
        title: Text(l.messageInfo),
      ),
      body:
          m == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 320),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [c.bubbleOut, c.bubbleOutEnd],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        m.deleted ? l.youDeletedMessage : (m.preview(l)),
                        style: t.bodyLarge?.copyWith(color: c.onBubbleOut),
                      ),
                    ),
                  ),
                  section(
                    l.infoRead,
                    Icons.done_all_rounded,
                    const Color(0xFF1E9BC4),
                    groups[SendStatus.read]!,
                  ),
                  section(
                    l.infoDelivered,
                    Icons.done_all_rounded,
                    c.textSecondary,
                    groups[SendStatus.delivered]!,
                  ),
                  section(
                    l.infoSent,
                    Icons.done_rounded,
                    c.textSecondary,
                    groups[SendStatus.sent]!,
                  ),
                ],
              ),
    );
  }
}
