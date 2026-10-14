import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/theme/hushlo_colors.dart';
import '../../../../core/widgets/confirm_sign_out.dart';
import '../../../attachments/presentation/viewmodels/attachment_providers.dart';
import '../../../auth/presentation/viewmodels/auth_providers.dart';
import '../viewmodels/profile_setup_view_model.dart';

/// Name + username (+ optional photo/bio) with a short privacy primer.
/// Finishing creates the profile; the router then moves on to Chats.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _bio = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final x = await ref
        .read(imagePickerProvider)
        .pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (x != null) {
      ref.read(profileSetupViewModelProvider.notifier).setAvatar(File(x.path));
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(profileSetupViewModelProvider.notifier)
        .submit(
          username: _username.text,
          displayName: _name.text,
          bio: _bio.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final s = ref.watch(profileSetupViewModelProvider);

    final (String hint, Color hintColor, IconData? hintIcon) = switch (s
        .username) {
      UsernameStatus.available => (
        l.usernameAvailable,
        c.success,
        Icons.check_circle_rounded,
      ),
      UsernameStatus.taken => (
        l.errUsernameTaken,
        c.error,
        Icons.cancel_rounded,
      ),
      UsernameStatus.invalid => (
        l.errUsernameInvalid,
        c.error,
        Icons.error_outline_rounded,
      ),
      UsernameStatus.checking => (l.usernameChecking, c.textSecondary, null),
      UsernameStatus.error => (
        l.usernameCheckFailed,
        c.warning,
        Icons.info_outline_rounded,
      ),
      UsernameStatus.idle => (l.usernameHelp, c.textSecondary, null),
    };

    final blocked =
        s.busy ||
        s.username == UsernameStatus.taken ||
        s.username == UsernameStatus.checking;

    return Scaffold(
      body: Column(
        children: [
          // ---- gradient header with overlapping avatar ----
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(bottom: 70),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      c.bubbleOut,
                      c.bubbleOutEnd,
                      c.accent.withValues(alpha: 0.9),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(36),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              l.setupTitle,
                              style: t.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            if (await confirmSignOut(context)) {
                              await ref.read(authRepositoryProvider).signOut();
                            }
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                          ),
                          child: Text(l.signOut),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: -52,
                child: Center(
                  child: Semantics(
                    button: true,
                    label: l.chooseAvatar,
                    child: GestureDetector(
                      onTap: s.busy ? null : _pickAvatar,
                      child: Stack(
                        children: [
                          Container(
                            width: 112,
                            height: 112,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: c.background,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              backgroundColor: c.primaryContainer,
                              backgroundImage:
                                  s.avatar != null
                                      ? FileImage(s.avatar!)
                                      : null,
                              child:
                                  s.avatar == null
                                      ? Icon(
                                        Icons.person_rounded,
                                        size: 52,
                                        color: c.primary,
                                      )
                                      : null,
                            ),
                          ),
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: c.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: c.background,
                                  width: 3,
                                ),
                              ),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                size: 17,
                                color: c.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // ---- form ----
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 64, 24, 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Text(l.avatarOptional, style: t.bodySmall),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _name,
                          enabled: !s.busy,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          maxLength: AppConfig.maxDisplayNameLength,
                          decoration: InputDecoration(
                            labelText: l.displayName,
                            counterText: '',
                            prefixIcon: const Icon(Icons.badge_outlined),
                          ),
                          validator:
                              (v) =>
                                  (v ?? '').trim().isEmpty
                                      ? l.errDisplayNameInvalid
                                      : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _username,
                          enabled: !s.busy,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9_@]'),
                            ),
                            LengthLimitingTextInputFormatter(21),
                          ],
                          onChanged:
                              ref
                                  .read(profileSetupViewModelProvider.notifier)
                                  .usernameChanged,
                          decoration: InputDecoration(
                            labelText: l.username,
                            prefixIcon: const Icon(
                              Icons.alternate_email_rounded,
                            ),
                            suffixIcon:
                                s.username == UsernameStatus.checking
                                    ? const Padding(
                                      padding: EdgeInsets.all(15),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                    : (hintIcon == null
                                        ? null
                                        : Icon(hintIcon, color: hintColor)),
                          ),
                          validator:
                              (v) =>
                                  s.username == UsernameStatus.invalid ||
                                          (v ?? '').trim().isEmpty
                                      ? l.errUsernameInvalid
                                      : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 6),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              hint,
                              style: t.bodySmall?.copyWith(color: hintColor),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _bio,
                          enabled: !s.busy,
                          maxLength: AppConfig.maxBioLength,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: l.bioOptional,
                            alignLabelWithHint: true,
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 22),
                              child: Icon(Icons.notes_rounded),
                            ),
                          ),
                        ),
                        if (s.failure != null &&
                            s.username != UsernameStatus.taken)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              failureMessage(l, s.failure!),
                              style: t.bodyMedium?.copyWith(color: c.error),
                            ),
                          ),
                        const SizedBox(height: 12),
                        const _PrimerCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ---- pinned action ----
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            decoration: BoxDecoration(
              color: c.background,
              border: Border(
                top: BorderSide(color: c.outline.withValues(alpha: 0.7)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: FilledButton(
                    onPressed: blocked ? null : _submit,
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
                            : Text(l.continueLabel),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Concise privacy primer. Honest about what v1 is (not end-to-end encrypted).
class _PrimerCard extends StatelessWidget {
  const _PrimerCard();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    Widget row(IconData i, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: c.primaryContainer,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(i, size: 16, color: c.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: c.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.primerTitle, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          row(Icons.search_rounded, l.primerDiscover),
          row(Icons.cloud_outlined, l.primerStorage),
          row(Icons.notifications_none_rounded, l.primerNotifications),
          row(Icons.lock_open_rounded, l.primerNotE2ee),
        ],
      ),
    );
  }
}
