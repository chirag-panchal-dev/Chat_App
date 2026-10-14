import 'package:flutter/material.dart';

import '../l10n/l10n_ext.dart';

/// Asks "Sign out?" and returns true if the user confirms.
Future<bool> confirmSignOut(BuildContext context) async {
  final l = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: Text(l.signOutTitle),
          content: Text(l.signOutBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.signOut),
            ),
          ],
        ),
  );
  return ok == true;
}
