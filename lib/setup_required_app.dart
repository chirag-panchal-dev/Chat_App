import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/hushlo_mark.dart';

/// Shown instead of the app when Firebase has not been configured, so a fresh
/// checkout fails loudly and helpfully rather than with a crash.
/// This is a developer-facing screen, intentionally English-only.
class SetupRequiredApp extends StatelessWidget {
  const SetupRequiredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HushloMark(size: 72),
                SizedBox(height: 24),
                Text(
                  'Firebase is not configured',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 12),
                Text(
                  'Run `flutterfire configure` in the project root to link a '
                  'Firebase project and generate lib/firebase_options.dart, '
                  'then rebuild. See README.md for the full setup.',
                  style: TextStyle(fontSize: 16, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
