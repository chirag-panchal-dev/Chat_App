import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_ext.dart';
import '../../../core/theme/hushlo_colors.dart';
import 'chat_theme_scope.dart';
import 'chat_theme_sheet.dart';

/// Row in the contact / group info screens that shows and changes this
/// user's own chat theme.
class ChatThemeTile extends ConsumerWidget {
  const ChatThemeTile({
    super.key,
    required this.conversationId,
    required this.me,
  });

  final String conversationId;
  final String me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.colors;
    final current = ref.watch(chatThemeProvider(conversationId));
    return ListTile(
      leading: Icon(Icons.palette_outlined, color: c.primary),
      title: Text(l.chatTheme),
      subtitle: Text(chatThemeName(l, current?.id)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap:
          () => showChatThemeSheet(
            context,
            conversationId: conversationId,
            me: me,
          ),
    );
  }
}
