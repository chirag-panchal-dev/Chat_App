import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/l10n/l10n_ext.dart';
import '../../../auth/presentation/viewmodels/auth_providers.dart';
import '../../domain/safety_repository.dart';
import '../viewmodels/safety_providers.dart';

/// Shows the report flow (reason + optional context) and a confirmation.
Future<void> showReportDialog(
  BuildContext context,
  WidgetRef ref, {
  required String reportedUid,
  String? conversationId,
  String? messageId,
}) async {
  final l = context.l10n;
  final me = ref.read(currentUidProvider);
  if (me == null) return;
  final result = await showDialog<_ReportInput>(
    context: context,
    builder: (_) => const _ReportDialog(),
  );
  if (result == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref
        .read(safetyRepositoryProvider)
        .report(
          reporterId: me,
          reportedUid: reportedUid,
          reason: result.reason,
          details: result.details,
          conversationId: conversationId,
          messageId: messageId,
        );
    messenger.showSnackBar(SnackBar(content: Text(l.reportSent)));
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(failureMessage(l, Failure.from(e)))),
    );
  }
}

class _ReportInput {
  const _ReportInput(this.reason, this.details);
  final ReportReason reason;
  final String details;
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();
  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  ReportReason _reason = ReportReason.spam;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  String _label(AppL10n l, ReportReason r) => switch (r) {
    ReportReason.spam => l.reasonSpam,
    ReportReason.harassment => l.reasonHarassment,
    ReportReason.inappropriate => l.reasonInappropriate,
    ReportReason.impersonation => l.reasonImpersonation,
    ReportReason.other => l.reasonOther,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.reportTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.reportBody),
            const SizedBox(height: 8),
            for (final r in ReportReason.values)
              RadioListTile<ReportReason>(
                value: r,
                groupValue: _reason,
                onChanged: (v) => setState(() => _reason = v ?? _reason),
                contentPadding: EdgeInsets.zero,
                title: Text(_label(l, r)),
              ),
            TextField(
              controller: _details,
              maxLength: 500,
              maxLines: 3,
              decoration: InputDecoration(labelText: l.reportDetails),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
          onPressed:
              () =>
                  Navigator.pop(context, _ReportInput(_reason, _details.text)),
          child: Text(l.report),
        ),
      ],
    );
  }
}
