import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/theme/hushlo_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/hushlo_mark.dart';
import '../viewmodels/auth_view_model.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.initialMode = AuthMode.signUp});
  final AuthMode initialMode;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () =>
          ref.read(authViewModelProvider.notifier).setMode(widget.initialMode),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    ref
        .read(authViewModelProvider.notifier)
        .submit(_email.text, _password.text);
  }

  bool get _showApple => !kIsWeb && Platform.isIOS && AppConfig.appleSignIn;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final s = ref.watch(authViewModelProvider);
    final vm = ref.read(authViewModelProvider.notifier);
    final isSignUp = s.mode == AuthMode.signUp;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFF0C131A),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.7, -1),
            radius: 1.4,
            colors: [Color(0xFF16424A), Color(0xFF0C131A)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: l.back,
                  color: Colors.white,
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.go('/intro'),
                ),
              ),
              const HushloMark(size: 64),
              const SizedBox(height: 10),
              Text(
                l.welcomeTagline,
                style: t.bodyMedium?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: c.background,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: AutofillGroup(
                          child: Form(
                            key: _form,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Semantics(
                                  header: true,
                                  child: Text(
                                    isSignUp ? l.createAccount : l.welcomeBack,
                                    style: t.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: _email,
                                  enabled: !s.busy,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: l.email,
                                    prefixIcon: const Icon(
                                      Icons.mail_outline_rounded,
                                    ),
                                  ),
                                  validator:
                                      (v) =>
                                          FieldValidators.isEmail(v ?? '')
                                              ? null
                                              : l.errInvalidEmail,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _password,
                                  enabled: !s.busy,
                                  obscureText: _obscure,
                                  autofillHints: [
                                    isSignUp
                                        ? AutofillHints.newPassword
                                        : AutofillHints.password,
                                  ],
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  decoration: InputDecoration(
                                    labelText: l.password,
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                    ),
                                    suffixIcon: IconButton(
                                      tooltip:
                                          _obscure
                                              ? l.showPassword
                                              : l.hidePassword,
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed:
                                          () => setState(
                                            () => _obscure = !_obscure,
                                          ),
                                    ),
                                  ),
                                  validator:
                                      (v) =>
                                          (v ?? '').length >= 8
                                              ? null
                                              : l.errWeakPassword,
                                ),
                                if (!isSignUp)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed:
                                          s.busy
                                              ? null
                                              : () =>
                                                  vm.resetPassword(_email.text),
                                      child: Text(l.forgotPassword),
                                    ),
                                  ),
                                if (s.failure != null)
                                  _Message(
                                    text: failureMessage(l, s.failure!),
                                    color: c.error,
                                    icon: Icons.error_outline_rounded,
                                  ),
                                if (s.resetSent)
                                  _Message(
                                    text: l.resetEmailSent,
                                    color: c.success,
                                    icon: Icons.check_circle_outline_rounded,
                                  ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: s.busy ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(56),
                                    shape: const StadiumBorder(),
                                  ),
                                  child:
                                      s.busy
                                          ? SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: c.onPrimary,
                                            ),
                                          )
                                          : Text(
                                            isSignUp
                                                ? l.createAccount
                                                : l.signIn,
                                          ),
                                ),
                                if (AppConfig.socialSignIn) ...[
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      const Expanded(child: Divider()),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: Text(l.or, style: t.bodySmall),
                                      ),
                                      const Expanded(child: Divider()),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  OutlinedButton.icon(
                                    onPressed: s.busy ? null : vm.google,
                                    style: OutlinedButton.styleFrom(
                                      shape: const StadiumBorder(),
                                    ),
                                    icon: const Icon(
                                      Icons.g_mobiledata_rounded,
                                      size: 30,
                                    ),
                                    label: Text(l.continueWithGoogle),
                                  ),
                                  if (_showApple) ...[
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: s.busy ? null : vm.apple,
                                      style: OutlinedButton.styleFrom(
                                        shape: const StadiumBorder(),
                                      ),
                                      icon: const Icon(Icons.apple_rounded),
                                      label: Text(l.continueWithApple),
                                    ),
                                  ],
                                ],
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed:
                                      s.busy
                                          ? null
                                          : () => vm.setMode(
                                            isSignUp
                                                ? AuthMode.login
                                                : AuthMode.signUp,
                                          ),
                                  child: Text(
                                    isSignUp ? l.haveAccount : l.needAccount,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.color, required this.icon});
  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    ),
  );
}
