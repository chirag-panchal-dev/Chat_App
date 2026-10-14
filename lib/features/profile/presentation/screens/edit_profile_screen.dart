import '../../../../core/widgets/hushlo_back_button.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/theme/hushlo_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../attachments/presentation/viewmodels/attachment_providers.dart';
import '../../../auth/presentation/viewmodels/auth_providers.dart';
import '../viewmodels/profile_providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _bio;
  File? _avatar;
  bool _busy = false;
  Failure? _failure;

  @override
  void initState() {
    super.initState();
    final p = ref.read(currentProfileProvider).value;
    _name = TextEditingController(text: p?.displayName ?? '');
    _bio = TextEditingController(text: p?.bio ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final x = await ref
        .read(imagePickerProvider)
        .pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (x != null) setState(() => _avatar = File(x.path));
  }

  Future<void> _save() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    if (_name.text.trim().isEmpty) {
      setState(
        () =>
            _failure = const ValidationFailure(
              ValidationReason.displayNameInvalid,
            ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final repo = ref.read(profileRepositoryProvider);
      String? photo;
      if (_avatar != null) {
        final processed = await ref
            .read(imageProcessorProvider)
            .processAvatar(_avatar!);
        photo = await repo.uploadAvatar(uid, processed);
      }
      await repo.updateProfile(
        uid: uid,
        displayName: _name.text,
        bio: _bio.text,
        photoPath: photo,
      );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) setState(() => _failure = Failure.from(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final p = ref.watch(currentProfileProvider).value;
    return Scaffold(
      appBar: AppBar(
        leading: const HushloBackButton(),
        leadingWidth: 60,
        title: Text(l.editProfile),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Semantics(
                button: true,
                label: l.chooseAvatar,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _busy ? null : _pick,
                  child:
                      _avatar != null
                          ? CircleAvatar(
                            radius: 48,
                            backgroundImage: FileImage(_avatar!),
                          )
                          : UserAvatar(
                            name: p?.displayName ?? '',
                            photoPath: p?.photoPath,
                            size: 96,
                          ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _name,
              enabled: !_busy,
              maxLength: AppConfig.maxDisplayNameLength,
              decoration: InputDecoration(
                labelText: l.displayName,
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: InputDecoration(
                labelText: l.username,
                helperText: l.usernameLocked,
                enabled: false,
              ),
              child: Text('@${p?.username ?? ''}'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bio,
              enabled: !_busy,
              maxLines: 2,
              maxLength: AppConfig.maxBioLength,
              decoration: InputDecoration(labelText: l.bioOptional),
            ),
            if (_failure != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  failureMessage(l, _failure!),
                  style: TextStyle(color: c.error),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child:
                  _busy
                      ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: c.onPrimary,
                        ),
                      )
                      : Text(l.save),
            ),
          ],
        ),
      ),
    );
  }
}
