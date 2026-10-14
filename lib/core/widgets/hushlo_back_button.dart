import 'package:flutter/material.dart';

import '../l10n/l10n_ext.dart';
import '../theme/hushlo_colors.dart';

/// Round, softly tinted back button used across the app (replaces the plain
/// arrow). Use [onDark] on gradient/dark headers. Hit area is 48dp.
class HushloBackButton extends StatelessWidget {
  const HushloBackButton({
    super.key,
    this.onPressed,
    this.onDark = false,
    this.icon = Icons.arrow_back_ios_new_rounded,
    this.tooltip,
  });

  final VoidCallback? onPressed;
  final bool onDark;
  final IconData icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = onDark ? Colors.white.withValues(alpha: 0.18) : c.surfaceSubtle;
    final fg = onDark ? Colors.white : c.textPrimary;
    return Semantics(
      button: true,
      label: tooltip ?? context.l10n.back,
      child: Tooltip(
        message: tooltip ?? context.l10n.back,
        child: InkResponse(
          radius: 26,
          onTap: onPressed ?? () => Navigator.of(context).maybePop(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, size: 17, color: fg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
