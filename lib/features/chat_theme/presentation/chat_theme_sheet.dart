import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_ext.dart';
import '../../../core/theme/hushlo_colors.dart';
import '../../conversations/presentation/viewmodels/conversation_providers.dart';
import '../domain/chat_theme.dart';
import 'chat_theme_scope.dart';

String chatThemeName(AppL10n l, String? id) => switch (id) {
  'ocean' => l.themeOcean,
  'violet' => l.themeViolet,
  'rose' => l.themeRose,
  'sunset' => l.themeSunset,
  'forest' => l.themeForest,
  'graphite' => l.themeGraphite,
  _ => l.chatThemeDefault,
};

/// Opens the picker: tap a preview to apply it to this chat immediately.
Future<void> showChatThemeSheet(
  BuildContext context, {
  required String conversationId,
  required String me,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _ChatThemeSheet(conversationId: conversationId, me: me),
);

class _ChatThemeSheet extends ConsumerWidget {
  const _ChatThemeSheet({required this.conversationId, required this.me});
  final String conversationId;
  final String me;

  Future<void> _pick(BuildContext context, WidgetRef ref, String? id) async {
    final l = context.l10n;
    try {
      await ref
          .read(conversationRepositoryProvider)
          .setChatTheme(conversationId, me, id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.chatThemeFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.colors;
    final current = ref.watch(chatThemeProvider(conversationId))?.id;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // The sheet inherits the chat's current theme, so the Default preview
    // uses the app's own palette explicitly.
    final base = dark ? HushloColors.dark : HushloColors.light;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.chatTheme, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              l.chatThemeHint,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
              children: [
                _Swatch(
                  label: l.chatThemeDefault,
                  selected: current == null,
                  selectedLabel: l.chatThemeSelected,
                  wallpaper: base.chatBackground,
                  bubble: base.bubbleOut,
                  bubbleEnd: base.bubbleOutEnd,
                  bubbleIn: base.bubbleIn,
                  onTap: () => _pick(context, ref, null),
                ),
                for (final t in chatThemes)
                  _Swatch(
                    label: chatThemeName(l, t.id),
                    selected: current == t.id,
                    selectedLabel: l.chatThemeSelected,
                    wallpaper: dark ? t.wallpaperDark : t.wallpaperLight,
                    bubble: t.bubble,
                    bubbleEnd: t.bubbleEnd,
                    bubbleIn: c.bubbleIn,
                    onTap: () => _pick(context, ref, t.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A miniature chat: wallpaper with one received and one sent bubble.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.label,
    required this.selected,
    required this.selectedLabel,
    required this.wallpaper,
    required this.bubble,
    required this.bubbleEnd,
    required this.bubbleIn,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final String selectedLabel;
  final Color wallpaper;
  final Color bubble;
  final Color bubbleEnd;
  final Color bubbleIn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: selected ? '$label, $selectedLabel' : label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: wallpaper,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? c.primary : c.outline,
                    width: selected ? 2.5 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        width: 38,
                        height: 18,
                        decoration: BoxDecoration(
                          color: bubbleIn,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 46,
                        height: 20,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [bubble, bubbleEnd]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    if (selected)
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 22,
                          color: c.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: selected ? FontWeight.w700 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
