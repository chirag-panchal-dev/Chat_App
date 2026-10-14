import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/widgets/confirm_sign_out.dart';
import '../../../../core/theme/hushlo_colors.dart';
import '../../../../core/widgets/state_views.dart';
import '../viewmodels/auth_providers.dart';

/// Verification-pending screen with resend (cooldown) and periodic re-check.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  Timer? _poll;
  Timer? _cooldownTimer;
  int _cooldown = 0;
  bool _checking = false;
  Failure? _failure;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _check(silent: true),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    if (!silent) setState(() => _checking = true);
    try {
      await ref.read(authRepositoryProvider).reloadUser();
    } catch (_) {
      /* surfaced only on explicit taps */
    } finally {
      if (mounted && !silent) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _failure = null;
      _sent = false;
    });
    try {
      await ref.read(authRepositoryProvider).sendEmailVerification();
      if (!mounted) return;
      setState(() {
        _sent = true;
        _cooldown = 60;
      });
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted || _cooldown <= 1) {
          t.cancel();
          if (mounted) setState(() => _cooldown = 0);
        } else {
          setState(() => _cooldown--);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _failure = Failure.from(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final email = ref.watch(authStateProvider).value?.email ?? '';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EmptyState(
                    illustration: 'assets/illustrations/verify_email.png',
                    icon: Icons.mark_email_unread_outlined,
                    title: l.verifyEmailTitle,
                    message: l.verifyEmailBody(email),
                  ),
                  const SizedBox(height: 24),
                  if (_failure != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        failureMessage(l, _failure!),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.error),
                      ),
                    ),
                  if (_sent)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        l.verificationSent,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.success),
                      ),
                    ),
                  FilledButton(
                    onPressed: _checking ? null : () => _check(),
                    child: Text(l.iVerified),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _cooldown > 0 ? null : _resend,
                    child: Text(
                      _cooldown > 0 ? l.resendIn(_cooldown) : l.resendEmail,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (await confirmSignOut(context)) {
                        await ref.read(authRepositoryProvider).signOut();
                      }
                    },
                    child: Text(l.signOut),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
