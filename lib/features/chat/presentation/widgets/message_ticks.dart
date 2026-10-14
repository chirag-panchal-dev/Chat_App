import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/theme/hushlo_colors.dart';
import '../../domain/entities/chat_message.dart';

/// WhatsApp-style status: clock (sending), ✓ (sent), ✓✓ (delivered),
/// bright ✓✓ (read). Shape differs per state, so it never relies on colour
/// alone, and it carries a semantic label.
class MessageTicks extends StatelessWidget {
  const MessageTicks({
    super.key,
    required this.status,
    required this.baseColor,
    this.size = 16,
  });

  final SendStatus status;
  final Color baseColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final (IconData icon, String label, Color color) = switch (status) {
      SendStatus.sending => (
        Icons.schedule_rounded,
        l.statusSending,
        baseColor,
      ),
      SendStatus.sent => (Icons.done_rounded, l.statusSent, baseColor),
      SendStatus.delivered => (
        Icons.done_all_rounded,
        l.statusDelivered,
        baseColor,
      ),
      SendStatus.read => (Icons.done_all_rounded, l.statusRead, c.tickRead),
      SendStatus.failed => (Icons.error_outline_rounded, l.sendFailed, c.error),
    };
    return Semantics(
      label: label,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        child: Icon(icon, key: ValueKey(status), size: size, color: color),
      ),
    );
  }
}
