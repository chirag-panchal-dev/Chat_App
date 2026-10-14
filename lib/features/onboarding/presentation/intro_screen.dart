import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_ext.dart';

/// Premium intro: dark hero with illustration, one headline, three short
/// value points and two clear actions. No carousel.
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  static const _ink = Color(0xFF0C131A);
  static const _teal = Color(0xFF43CDB8);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _teal.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: _teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: t.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.86),
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: _ink,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.6, -0.9),
            radius: 1.3,
            colors: [Color(0xFF16424A), _ink],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Center(
                        child: ExcludeSemantics(
                          child: Image.asset(
                            'assets/illustrations/intro_hero.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      header: true,
                      child: Text(
                        l.introHeadline,
                        style: t.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontSize: 32,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l.introBody,
                      style: t.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 18),
                    point(Icons.alternate_email_rounded, l.featurePrivate),
                    point(Icons.notifications_none_rounded, l.featureCalm),
                    point(Icons.groups_2_outlined, l.featureNoFeed),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () => context.go('/auth?mode=signup'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _teal,
                        foregroundColor: _ink,
                        minimumSize: const Size.fromHeight(56),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(l.getStarted),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => context.go('/auth?mode=login'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: Text(l.haveAccount),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
