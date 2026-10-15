import 'package:flutter/material.dart';

import '../../../core/theme/hushlo_colors.dart';

/// A per-chat look: the colour of your own bubbles and the chat wallpaper.
/// Personal: it is stored in your own member doc, so only you see it.
@immutable
class ChatTheme {
  const ChatTheme({
    required this.id,
    required this.bubble,
    required this.bubbleEnd,
    required this.wallpaperLight,
    required this.wallpaperDark,
  });

  /// Stored value (and the key the security rules allow).
  final String id;

  /// Your outgoing bubble gradient (dark enough for white text).
  final Color bubble;
  final Color bubbleEnd;

  final Color wallpaperLight;
  final Color wallpaperDark;

  /// [base] with this theme's bubble colours and wallpaper.
  HushloColors apply(HushloColors base, Brightness brightness) => base.copyWith(
    bubbleOut: bubble,
    bubbleOutEnd: bubbleEnd,
    chatBackground:
        brightness == Brightness.dark ? wallpaperDark : wallpaperLight,
  );
}

/// Choices offered in the picker, in display order. The default look is not a
/// theme: no `chatTheme` value stored means "use the app theme".
const chatThemes = <ChatTheme>[
  ChatTheme(
    id: 'ocean',
    bubble: Color(0xFF2468C9),
    bubbleEnd: Color(0xFF184E9E),
    wallpaperLight: Color(0xFFE4ECF7),
    wallpaperDark: Color(0xFF0A121C),
  ),
  ChatTheme(
    id: 'violet',
    bubble: Color(0xFF6A54D6),
    bubbleEnd: Color(0xFF4F3DB0),
    wallpaperLight: Color(0xFFEBE7F7),
    wallpaperDark: Color(0xFF110E1D),
  ),
  ChatTheme(
    id: 'rose',
    bubble: Color(0xFFC23F70),
    bubbleEnd: Color(0xFF9C2A58),
    wallpaperLight: Color(0xFFF6E7EE),
    wallpaperDark: Color(0xFF1B0D13),
  ),
  ChatTheme(
    id: 'sunset',
    bubble: Color(0xFFB05620),
    bubbleEnd: Color(0xFF8F4313),
    wallpaperLight: Color(0xFFF8EDE2),
    wallpaperDark: Color(0xFF1A120A),
  ),
  ChatTheme(
    id: 'forest',
    bubble: Color(0xFF267D4C),
    bubbleEnd: Color(0xFF1A5F38),
    wallpaperLight: Color(0xFFE3F0E8),
    wallpaperDark: Color(0xFF0B150F),
  ),
  ChatTheme(
    id: 'graphite',
    bubble: Color(0xFF4A5A66),
    bubbleEnd: Color(0xFF35424B),
    wallpaperLight: Color(0xFFE6E9EC),
    wallpaperDark: Color(0xFF101315),
  ),
];

/// The theme for a stored id, or null (default look) for null / unknown ids,
/// so an id from a newer app version never breaks an older one.
ChatTheme? chatThemeById(String? id) {
  for (final t in chatThemes) {
    if (t.id == id) return t;
  }
  return null;
}

/// WCAG contrast ratio of two colours (1 to 21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
