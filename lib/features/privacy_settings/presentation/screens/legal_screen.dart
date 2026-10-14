import '../../../../core/widgets/hushlo_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../../core/l10n/l10n_ext.dart';

/// Shows a bundled legal draft. These are drafts and must be reviewed by a
/// qualified professional before release (stated on-screen).
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});
  final String doc; // privacy | terms | community

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title = switch (doc) {
      'privacy' => l.privacyPolicy,
      'terms' => l.terms,
      _ => l.communityGuidelines,
    };
    return Scaffold(
      appBar: AppBar(
        leading: const HushloBackButton(),
        leadingWidth: 60,
        title: Text(title),
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString('assets/legal/$doc.txt'),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: SelectableText(
              snap.data!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        },
      ),
    );
  }
}
