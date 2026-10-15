import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/hushlo_colors.dart';
import '../../conversations/presentation/viewmodels/conversation_providers.dart';
import '../domain/chat_theme.dart';

/// The signed-in user's chosen [ChatTheme] for [conversationId] (null = the
/// default app look).
final chatThemeProvider = Provider.autoDispose.family<ChatTheme?, String>(
  (ref, cid) =>
      chatThemeById(ref.watch(memberPrefsProvider(cid)).value?.chatTheme),
);

/// Re-themes everything below it (bubbles, wallpaper) for one chat.
class ChatThemeScope extends ConsumerWidget {
  const ChatThemeScope({
    super.key,
    required this.conversationId,
    required this.child,
  });

  final String conversationId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(chatThemeProvider(conversationId));
    if (theme == null) return child;
    final base = Theme.of(context);
    final colors = theme.apply(context.colors, base.brightness);
    return Theme(data: base.copyWith(extensions: [colors]), child: child);
  }
}
