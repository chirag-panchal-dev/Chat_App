import 'package:flutter/material.dart';

/// Centralised design tokens (spec §5.2). Widgets read colours from here or
/// from the derived [ColorScheme]; no hard-coded colours in feature code.
@immutable
class HushloColors extends ThemeExtension<HushloColors> {
  const HushloColors({
    required this.background,
    required this.surface,
    required this.surfaceSubtle,
    required this.primary,
    required this.primaryContainer,
    required this.onPrimary,
    required this.textPrimary,
    required this.textSecondary,
    required this.outline,
    required this.success,
    required this.warning,
    required this.error,
    required this.bubbleOut,
    required this.onBubbleOut,
    required this.bubbleIn,
    required this.onBubbleIn,
    required this.bubbleOutEnd,
    required this.accent,
    required this.chatBackground,
    required this.tickRead,
  });

  final Color background;
  final Color surface;
  final Color surfaceSubtle;
  final Color primary;
  final Color primaryContainer;
  final Color onPrimary;
  final Color textPrimary;
  final Color textSecondary;
  final Color outline;
  final Color success;
  final Color warning;
  final Color error;
  final Color bubbleOut;
  final Color onBubbleOut;
  final Color bubbleIn;
  final Color onBubbleIn;
  final Color bubbleOutEnd;
  final Color accent;
  final Color chatBackground;
  final Color tickRead;

  static const light = HushloColors(
    background: Color(0xFFF4F7F8),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFF0F3F7),
    primary: Color(0xFF176B67),
    primaryContainer: Color(0xFFD9F4EF),
    onPrimary: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF152129),
    textSecondary: Color(0xFF63717B),
    outline: Color(0xFFE2E8EC),
    success: Color(0xFF21865D),
    warning: Color(0xFFB56B16),
    error: Color(0xFFC74646),
    bubbleOut: Color(0xFF1B837D),
    onBubbleOut: Color(0xFFFFFFFF),
    bubbleIn: Color(0xFFFFFFFF),
    onBubbleIn: Color(0xFF152129),
    bubbleOutEnd: Color(0xFF135F5B),
    accent: Color(0xFF6E63E8),
    chatBackground: Color(0xFFE8EEF0),
    tickRead: Color(0xFF5CCBFF),
  );

  static const dark = HushloColors(
    background: Color(0xFF0F1518),
    surface: Color(0xFF171F23),
    surfaceSubtle: Color(0xFF202A2F),
    primary: Color(0xFF78D7C6),
    primaryContainer: Color(0xFF1B4945),
    onPrimary: Color(0xFF0E2624),
    textPrimary: Color(0xFFF1F5F6),
    textSecondary: Color(0xFFA2B0B6),
    outline: Color(0xFF344147),
    success: Color(0xFF5CC79A),
    warning: Color(0xFFE0A154),
    error: Color(0xFFEF8A8A),
    bubbleOut: Color(0xFF217A74),
    onBubbleOut: Color(0xFFF4FAFA),
    bubbleIn: Color(0xFF202A2F),
    onBubbleIn: Color(0xFFF1F5F6),
    bubbleOutEnd: Color(0xFF175C58),
    accent: Color(0xFFA79FFF),
    chatBackground: Color(0xFF0B1114),
    tickRead: Color(0xFF5CCBFF),
  );

  @override
  HushloColors copyWith() => this;

  @override
  HushloColors lerp(ThemeExtension<HushloColors>? other, double t) {
    if (other is! HushloColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return HushloColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceSubtle: l(surfaceSubtle, other.surfaceSubtle),
      primary: l(primary, other.primary),
      primaryContainer: l(primaryContainer, other.primaryContainer),
      onPrimary: l(onPrimary, other.onPrimary),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      outline: l(outline, other.outline),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      error: l(error, other.error),
      bubbleOut: l(bubbleOut, other.bubbleOut),
      onBubbleOut: l(onBubbleOut, other.onBubbleOut),
      bubbleIn: l(bubbleIn, other.bubbleIn),
      onBubbleIn: l(onBubbleIn, other.onBubbleIn),
      bubbleOutEnd: l(bubbleOutEnd, other.bubbleOutEnd),
      accent: l(accent, other.accent),
      chatBackground: l(chatBackground, other.chatBackground),
      tickRead: l(tickRead, other.tickRead),
    );
  }
}

extension HushloThemeContext on BuildContext {
  HushloColors get colors => Theme.of(this).extension<HushloColors>()!;
}
