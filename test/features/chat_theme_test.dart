import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hushlo/core/theme/hushlo_colors.dart';
import 'package:hushlo/features/auth/presentation/viewmodels/auth_providers.dart';
import 'package:hushlo/features/chat_theme/domain/chat_theme.dart';
import 'package:hushlo/features/chat_theme/presentation/chat_theme_scope.dart';
import 'package:hushlo/features/chat_theme/presentation/chat_theme_sheet.dart';
import 'package:hushlo/features/conversations/domain/entities/conversation.dart';
import 'package:hushlo/features/conversations/presentation/viewmodels/conversation_providers.dart';

import '../helpers/pump_app.dart';
import 'fakes.dart';

void main() {
  group('chat theme presets', () {
    test('ids are unique and look-up is forgiving', () {
      final ids = chatThemes.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(chatThemeById('ocean')?.id, 'ocean');
      expect(chatThemeById(null), isNull);
      expect(chatThemeById('from-a-newer-app'), isNull);
    });

    test('every preset keeps white text readable (WCAG AA, 4.5:1)', () {
      for (final t in chatThemes) {
        expect(
          contrastRatio(Colors.white, t.bubble),
          greaterThanOrEqualTo(4.5),
          reason: '${t.id} bubble',
        );
        expect(
          contrastRatio(Colors.white, t.bubbleEnd),
          greaterThanOrEqualTo(4.5),
          reason: '${t.id} bubbleEnd',
        );
      }
    });

    test('every preset id is allowed by the Firestore rules', () {
      final rules = File('firestore.rules').readAsStringSync();
      for (final t in chatThemes) {
        expect(rules, contains("'${t.id}'"), reason: t.id);
      }
    });

    test('apply swaps bubbles and wallpaper, keeps everything else', () {
      final t = chatThemeById('violet')!;
      final light = t.apply(HushloColors.light, Brightness.light);
      final dark = t.apply(HushloColors.dark, Brightness.dark);
      expect(light.bubbleOut, t.bubble);
      expect(light.chatBackground, t.wallpaperLight);
      expect(dark.chatBackground, t.wallpaperDark);
      expect(light.bubbleIn, HushloColors.light.bubbleIn);
      expect(light.primary, HushloColors.light.primary);
      expect(dark.surface, HushloColors.dark.surface);
    });
  });

  group('scope and picker', () {
    late FakeConversationRepository repo;
    setUp(() => repo = FakeConversationRepository());

    List<dynamic> overrides(String? themeId) => [
      currentUidProvider.overrideWithValue('me'),
      conversationRepositoryProvider.overrideWithValue(repo),
      memberPrefsProvider.overrideWith(
        (ref, cid) => Stream.value(MemberPrefs(chatTheme: themeId)),
      ),
    ];

    Color? seen;
    Widget probe() => Builder(
      builder: (context) {
        seen = context.colors.bubbleOut;
        return const SizedBox();
      },
    );

    testWidgets('a chat without a theme keeps the app look', (t) async {
      await t.pumpApp(
        ChatThemeScope(conversationId: 'a_b', child: probe()),
        overrides: overrides(null).cast(),
      );
      await t.pump();
      expect(seen, HushloColors.light.bubbleOut);
    });

    testWidgets('a chat with a theme is re-coloured below the scope', (
      t,
    ) async {
      await t.pumpApp(
        ChatThemeScope(conversationId: 'a_b', child: probe()),
        overrides: overrides('rose').cast(),
      );
      await t.pump();
      await t.pump();
      expect(seen, chatThemeById('rose')!.bubble);
    });

    testWidgets('picking a theme saves it; Default clears it', (t) async {
      await t.pumpApp(
        Builder(
          builder:
              (context) => ElevatedButton(
                onPressed:
                    () => showChatThemeSheet(
                      context,
                      conversationId: 'a_b',
                      me: 'me',
                    ),
                child: const Text('open'),
              ),
        ),
        overrides: overrides('violet').cast(),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.text('Chat theme'), findsOneWidget);
      expect(find.textContaining('Only you see this'), findsOneWidget);
      for (final n in [
        'Default',
        'Ocean',
        'Violet',
        'Rose',
        'Sunset',
        'Forest',
        'Graphite',
      ]) {
        expect(find.text(n), findsOneWidget, reason: n);
      }
      // Even in a themed chat the Default preview shows the app's own look.
      final swatches = t.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final defaultBg = (swatches.first.decoration! as BoxDecoration).color;
      expect(defaultBg, HushloColors.light.chatBackground);
      await t.tap(find.text('Ocean'));
      await t.pump();
      expect(repo.themes['a_b'], 'ocean');
      await t.tap(find.text('Default'));
      await t.pump();
      expect(repo.themes['a_b'], isNull);
      expect(repo.themes.containsKey('a_b'), isTrue);
    });
  });
}
