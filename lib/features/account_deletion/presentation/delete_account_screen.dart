import '../../../core/widgets/hushlo_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_ext.dart';
import '../../../core/theme/hushlo_colors.dart';
import '../../auth/presentation/viewmodels/auth_providers.dart';
import '../domain/account_deletion_repository.dart';
import 'delete_account_view_model.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _password = TextEditingController();
  final _details = TextEditingController();
  DeletionReason? _reason;
  bool _confirmed = false;

  @override
  void dispose() {
    _password.dispose();
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final s = ref.watch(deleteAccountViewModelProvider);
    final vm = ref.read(deleteAccountViewModelProvider.notifier);
    final user = ref.watch(authStateProvider).value;
    final working = s.phase == DeletePhase.working;

    Widget bullet(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: c.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: t.bodyMedium?.copyWith(height: 1.4)),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        leading: const HushloBackButton(),
        leadingWidth: 60,
        title: Text(l.deleteAccount),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            // Warning card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: c.error.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: c.error.withValues(alpha: 0.28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c.error.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: c.error,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l.deleteWhatTitle,
                          style: t.titleMedium?.copyWith(height: 1.25),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  bullet(Icons.person_off_outlined, l.deleteWhat1),
                  bullet(Icons.image_not_supported_outlined, l.deleteWhat2),
                  bullet(Icons.chat_bubble_outline_rounded, l.deleteWhat3),
                  bullet(Icons.people_outline_rounded, l.deleteWhat4),
                  Text(
                    l.deleteIrreversible,
                    style: t.bodyMedium?.copyWith(
                      color: c.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Reason
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.deleteReasonTitle, style: t.titleMedium),
                    const SizedBox(height: 2),
                    Text(l.deleteReasonHelp, style: t.bodySmall),
                    const SizedBox(height: 6),
                    for (final (r, label) in [
                      (DeletionReason.anotherAccount, l.reasonAnotherAccount),
                      (DeletionReason.privacy, l.reasonPrivacy),
                      (DeletionReason.notUsing, l.reasonNotUsing),
                      (DeletionReason.notifications, l.reasonNotifications),
                      (DeletionReason.betterApp, l.reasonBetterApp),
                      (DeletionReason.other, l.reasonOtherLeave),
                    ])
                      RadioListTile<DeletionReason>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        value: r,
                        groupValue: _reason,
                        onChanged:
                            working ? null : (v) => setState(() => _reason = v),
                        title: Text(label, style: t.bodyMedium),
                      ),
                    if (_reason != null) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _details,
                        enabled: !working,
                        maxLength: 500,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: l.deleteReasonDetails,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              value: _confirmed,
              onChanged:
                  working
                      ? null
                      : (v) => setState(() => _confirmed = v ?? false),
              title: Text(
                l.deleteConfirmCheck,
                style: t.bodyMedium?.copyWith(height: 1.35),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (s.phase == DeletePhase.needsReauth) ...[
              const SizedBox(height: 8),
              Text(l.reauthExplain, style: t.bodyMedium),
              const SizedBox(height: 12),
              if (user?.usesPassword ?? false) ...[
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l.password,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed:
                      () =>
                          vm.reauthenticateAndDelete(password: _password.text),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.error,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(l.confirmAndDelete),
                ),
              ] else
                FilledButton(
                  onPressed: () => vm.reauthenticateAndDelete(),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.error,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(l.confirmAndDelete),
                ),
            ] else ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed:
                    _confirmed && !working
                        ? () =>
                            vm.delete(reason: _reason, details: _details.text)
                        : null,
                style: FilledButton.styleFrom(
                  backgroundColor: c.error,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: c.surfaceSubtle,
                ),
                icon:
                    working
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.delete_forever_rounded),
                label: Text(l.deleteAccount),
              ),
            ],
            if (s.phase == DeletePhase.failed && s.failure != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    failureMessage(l, s.failure!),
                    style: t.bodyMedium?.copyWith(color: c.error),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
