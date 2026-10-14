import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/theme/hushlo_colors.dart';
import '../../../../core/widgets/hushlo_back_button.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../attachments/presentation/viewmodels/attachment_providers.dart';
import '../../../conversations/domain/entities/conversation.dart';
import '../../../profile/presentation/viewmodels/profile_providers.dart';
import '../../domain/group_rules.dart';
import '../viewmodels/group_builder_view_model.dart';
import '../widgets/contact_picker.dart';

/// Step 1: pick members. Step 2: name + optional photo. Creates the group and
/// opens it.
class NewGroupScreen extends ConsumerStatefulWidget {
  const NewGroupScreen({super.key});

  @override
  ConsumerState<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends ConsumerState<NewGroupScreen> {
  // You + up to 19 others.
  static const _capacity = maxGroupMembers - 1;
  int _step = 0;
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final x = await ref
        .read(imagePickerProvider)
        .pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (x != null) {
      ref.read(groupBuilderProvider(_capacity).notifier).setPhoto(File(x.path));
    }
  }

  Future<void> _create() async {
    final id = await ref
        .read(groupBuilderProvider(_capacity).notifier)
        .create(_name.text);
    if (id != null && mounted) context.pushReplacement('/chat/$id');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final s = ref.watch(groupBuilderProvider(_capacity));

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step == 1) setState(() => _step = 0);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: HushloBackButton(
            onPressed: () {
              if (_step == 1) {
                setState(() => _step = 0);
              } else {
                context.pop();
              }
            },
          ),
          leadingWidth: 60,
          title: Text(_step == 0 ? l.selectMembers : l.newGroup),
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child:
                _step == 0
                    ? Column(
                      key: const ValueKey('pick'),
                      children: [
                        const Expanded(
                          child: ContactPicker(capacity: _capacity),
                        ),
                        _BottomBar(
                          child: FilledButton(
                            onPressed:
                                s.selected.isEmpty
                                    ? null
                                    : () => setState(() => _step = 1),
                            child: Text(l.next),
                          ),
                        ),
                      ],
                    )
                    : Column(
                      key: const ValueKey('name'),
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              Center(
                                child: Semantics(
                                  button: true,
                                  label: l.groupPhotoOptional,
                                  child: GestureDetector(
                                    onTap: s.busy ? null : _pickPhoto,
                                    child: Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 54,
                                          backgroundColor: c.primaryContainer,
                                          backgroundImage:
                                              s.photo != null
                                                  ? FileImage(s.photo!)
                                                  : null,
                                          child:
                                              s.photo == null
                                                  ? Icon(
                                                    Icons.groups_rounded,
                                                    size: 52,
                                                    color: c.primary,
                                                  )
                                                  : null,
                                        ),
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: CircleAvatar(
                                            radius: 18,
                                            backgroundColor: c.primary,
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
                              const SizedBox(height: 6),
                              Center(
                                child: Text(
                                  l.groupPhotoOptional,
                                  style: t.bodySmall,
                                ),
                              ),
                              const SizedBox(height: 22),
                              TextField(
                                controller: _name,
                                enabled: !s.busy,
                                maxLength: GroupRules.maxNameLength,
                                textCapitalization: TextCapitalization.words,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: l.groupName,
                                  hintText: l.groupNameHint,
                                  counterText: '',
                                  prefixIcon: const Icon(Icons.groups_outlined),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                l.membersCount(s.selected.length + 1),
                                style: t.labelMedium,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  for (final uid in s.selected)
                                    _MemberAvatar(uid: uid),
                                ],
                              ),
                              if (s.failure != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 14),
                                  child: Text(
                                    failureMessage(l, s.failure!),
                                    style: t.bodyMedium?.copyWith(
                                      color: c.error,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        _BottomBar(
                          child: FilledButton(
                            onPressed:
                                s.busy || !GroupRules.isValidName(_name.text)
                                    ? null
                                    : _create,
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
                                    : Text(l.createGroup),
                          ),
                        ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }
}

class _MemberAvatar extends ConsumerWidget {
  const _MemberAvatar({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileByUidProvider(uid)).value;
    return Tooltip(
      message: p?.displayName ?? '',
      child: UserAvatar(
        name: p?.displayName ?? '?',
        photoPath: p?.photoPath,
        size: 40,
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(
          top: BorderSide(color: c.outline.withValues(alpha: 0.7)),
        ),
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}
