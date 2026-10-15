import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/navigation/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/app_lock/presentation/app_lock_gate.dart';
import 'features/chat/presentation/viewmodels/delivery_receipts_controller.dart';
import 'features/notifications/presentation/push_controller.dart';
import 'features/presence/presentation/presence_controller.dart';
import 'features/privacy_settings/presentation/viewmodels/settings_providers.dart';
import 'l10n/app_localizations.dart';

class HushloApp extends ConsumerWidget {
  const HushloApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep push registration/handling alive for the whole session.
    ref.watch(pushControllerProvider);
    ref.watch(deliveryReceiptsProvider);
    ref.watch(presenceControllerProvider);
    ref.watch(quietOffsetSyncProvider);

    return MaterialApp.router(
      onGenerateTitle: (ctx) => AppL10n.of(ctx).appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
      builder:
          (context, child) =>
              AppLockGate(child: child ?? const SizedBox.shrink()),
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppL10n.supportedLocales,
    );
  }
}
