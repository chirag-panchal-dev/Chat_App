import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hushlo/core/theme/app_theme.dart';
import 'package:hushlo/l10n/app_localizations.dart';

extension PumpApp on WidgetTester {
  /// Pumps [child] inside a localized, themed MaterialApp (+ ProviderScope).
  Future<void> pumpApp(
    Widget child, {
    List<Override> overrides = const [],
    double textScale = 1.0,
    ThemeMode mode = ThemeMode.light,
  }) => pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        localizationsDelegates: const [
          AppL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppL10n.supportedLocales,
        builder:
            (context, c) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: c!,
            ),
        home: child,
      ),
    ),
  );
}
