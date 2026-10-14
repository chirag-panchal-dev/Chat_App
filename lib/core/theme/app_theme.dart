import 'package:flutter/material.dart';

import 'hushlo_colors.dart';

/// Hushlo design system: Inter typography, soft layered surfaces, generous
/// radii and quiet motion. All colours come from [HushloColors].
abstract final class AppTheme {
  static ThemeData get light => _build(HushloColors.light, Brightness.light);
  static ThemeData get dark => _build(HushloColors.dark, Brightness.dark);

  static const _font = 'Inter';

  static ThemeData _build(HushloColors c, Brightness b) {
    final scheme = ColorScheme(
      brightness: b,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.textPrimary,
      secondary: c.accent,
      onSecondary: Colors.white,
      error: c.error,
      onError: b == Brightness.light ? Colors.white : const Color(0xFF2A0D0D),
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.background,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surfaceSubtle,
      surfaceContainerHigh: c.surfaceSubtle,
      surfaceContainerHighest: c.surfaceSubtle,
      outline: c.outline,
      outlineVariant: c.outline,
    );

    TextStyle t(
      double size,
      FontWeight w, {
      double? height,
      double spacing = 0,
      Color? color,
    }) => TextStyle(
      fontFamily: _font,
      fontSize: size,
      fontWeight: w,
      height: height,
      letterSpacing: spacing,
      color: color ?? c.textPrimary,
    );

    final text = TextTheme(
      displaySmall: t(34, FontWeight.w800, height: 1.12, spacing: -1.0),
      headlineLarge: t(32, FontWeight.w800, height: 1.15, spacing: -0.9),
      headlineMedium: t(28, FontWeight.w700, height: 1.18, spacing: -0.7),
      headlineSmall: t(24, FontWeight.w700, height: 1.22, spacing: -0.5),
      titleLarge: t(20, FontWeight.w700, height: 1.25, spacing: -0.35),
      titleMedium: t(16.5, FontWeight.w600, height: 1.3, spacing: -0.2),
      titleSmall: t(14, FontWeight.w600, height: 1.3, spacing: -0.05),
      bodyLarge: t(16, FontWeight.w400, height: 1.4, spacing: -0.15),
      bodyMedium: t(15, FontWeight.w400, height: 1.38, spacing: -0.1),
      bodySmall: t(13, FontWeight.w400, height: 1.35, color: c.textSecondary),
      labelLarge: t(15, FontWeight.w600, spacing: -0.1),
      labelMedium: t(
        12.5,
        FontWeight.w600,
        spacing: 0.2,
        color: c.textSecondary,
      ),
      labelSmall: t(
        11.5,
        FontWeight.w600,
        spacing: 0.3,
        color: c.textSecondary,
      ),
    );

    final radius16 = BorderRadius.circular(16);
    OutlineInputBorder border(Color color, [double w = 1]) =>
        OutlineInputBorder(
          borderRadius: radius16,
          borderSide: BorderSide(color: color, width: w),
        );

    final btnText = t(16, FontWeight.w600, spacing: -0.1);

    return ThemeData(
      useMaterial3: true,
      fontFamily: _font,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      extensions: [c],
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: c.textPrimary,
        titleTextStyle: t(20, FontWeight.w700, spacing: -0.4),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.outline),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: c.outline,
        space: 1,
        thickness: 0.8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        border: border(c.outline),
        enabledBorder: border(c.outline),
        focusedBorder: border(c.primary, 1.8),
        errorBorder: border(c.error),
        focusedErrorBorder: border(c.error, 1.8),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        labelStyle: t(15, FontWeight.w500, color: c.textSecondary),
        hintStyle: t(15, FontWeight.w400, color: c.textSecondary),
        helperStyle: t(12.5, FontWeight.w400, color: c.textSecondary),
        errorStyle: t(12.5, FontWeight.w500, color: c.error),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: const StadiumBorder(),
          textStyle: btnText,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: c.outline),
          shape: const StadiumBorder(),
          textStyle: btnText,
          foregroundColor: c.textPrimary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: t(15, FontWeight.w600, spacing: -0.1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        side: BorderSide(color: c.outline),
        shape: const StadiumBorder(),
        labelStyle: t(14, FontWeight.w600),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            b == Brightness.light ? const Color(0xFF1B262D) : c.surfaceSubtle,
        contentTextStyle: t(14.5, FontWeight.w500, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: t(20, FontWeight.w700, spacing: -0.4),
        contentTextStyle: t(
          15,
          FontWeight.w400,
          height: 1.4,
          color: c.textSecondary,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: t(15, FontWeight.w500),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 8,
        iconColor: c.textSecondary,
        titleTextStyle: t(16, FontWeight.w500, spacing: -0.15),
        subtitleTextStyle: t(
          13,
          FontWeight.w400,
          height: 1.35,
          color: c.textSecondary,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.outline,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.textSecondary,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: c.textSecondary, width: 1.5),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
    );
  }
}
