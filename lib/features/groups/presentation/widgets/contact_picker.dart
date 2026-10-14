import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/theme/hushlo_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../profile/presentation/viewmodels/profile_providers.dart';
import '../viewmodels/group_builder_view_model.dart';
import '../viewmodels/group_providers.dart';

/// Pick people from your chats, or add someone by exact username.
/// Selection state lives in [groupBuilderProvider] ([capacity] picks max).
class ContactPicker extends ConsumerStatefulWidget {
  const ContactPicker({
    super.key,
    required this.capacity,
    this.exclude = const {},
  });

  final int capacity;

  /// Uids that can't be picked (already in the group).
  final Set<String> exclude;

  @override
  ConsumerState<ContactPicker> createState() => _ContactPickerState();
}

class _ContactPickerState extends ConsumerState<ContactPicker> {
  final _search = TextEditingController();
  final _username = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    _username.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final s = ref.watch(groupBuilderProvider(widget.capacity));
    final vm = ref.read(groupBuilderProvider(widget.capacity).notifier);
    final contacts =
        ref
            .watch(directContactsProvider)
            .where((u) => !widget.exclude.contains(u))
            .toList();
    final extra = s.found.keys.where((u) => !contacts.contains(u)).toList();
    final all = [...extra, ...contacts];
    final q = _search.text.trim().toLowerCase();

    final noticeText = switch (s.notice) {
      'full' => l.memberLimitReached(widget.capacity),
      'notFound' => l.userNotFound,
      'self' => l.errSelfConversation,
      'already' => l.alreadyMember,
      _ => null,
    };

    return Column(
      children: [
        // Selected avatars
        if (s.selected.isNotEmpty)
          SizedBox(
            height: 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              itemCount: s.selected.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) {
                final uid = s.selected[i];
                return _SelectedChip(uid: uid, onRemove: () => vm.toggle(uid));
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.membersSelected(s.selected.length, widget.capacity),
                  style: t.labelMedium,
                ),
              ),
            ],
          ),
        ),
        // Search my chats
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: l.searchYourChats,
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: c.surfaceSubtle,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide(color: c.primary, width: 1.5),
              ),
            ),
          ),
        ),
        // Add by exact username
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: TextField(
            controller: _username,
            autocorrect: false,
            textInputAction: TextInputAction.search,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_@]')),
            ],
            onSubmitted: (v) {
              vm.addByUsername(v, exclude: widget.exclude);
              _username.clear();
            },
            decoration: InputDecoration(
              hintText: l.addByUsername,
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              suffixIcon:
                  s.lookupBusy
                      ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                      : IconButton(
                        tooltip: l.search,
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        onPressed: () {
                          vm.addByUsername(
                            _username.text,
                            exclude: widget.exclude,
                          );
                          _username.clear();
                        },
                      ),
            ),
          ),
        ),
        if (noticeText != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                liveRegion: true,
                child: Text(
                  noticeText,
                  style: t.bodySmall?.copyWith(color: c.warning),
                ),
              ),
            ),
          ),
        const SizedBox(height: 4),
        Expanded(
          child:
              all.isEmpty
                  ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l.noContactsYet,
                      textAlign: TextAlign.center,
                      style: t.bodyMedium?.copyWith(color: c.textSecondary),
                    ),
                  )
                  : ListView.builder(
                    itemCount: all.length,
                    itemBuilder:
                        (_, i) => _ContactRow(
                          uid: all[i],
                          query: q,
                          selected: s.selected.contains(all[i]),
                          onTap: () => vm.toggle(all[i]),
                        ),
                  ),
        ),
      ],
    );
  }
}

class _ContactRow extends ConsumerWidget {
  const _ContactRow({
    required this.uid,
    required this.query,
    required this.selected,
    required this.onTap,
  });

  final String uid;
  final String query;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final p = ref.watch(profileByUidProvider(uid)).value;
    final name = p?.displayName ?? '…';
    if (query.isNotEmpty &&
        !name.toLowerCase().contains(query) &&
        !(p?.username.toLowerCase().contains(query) ?? false)) {
      return const SizedBox.shrink();
    }
    return Semantics(
      selected: selected,
      label: name,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              UserAvatar(name: name, photoPath: p?.photoPath, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (p != null)
                      Text(
                        '@${p.username}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? c.primary : Colors.transparent,
                  border: Border.all(
                    color: selected ? c.primary : c.outline,
                    width: 1.6,
                  ),
                ),
                child:
                    selected
                        ? Icon(
                          Icons.check_rounded,
                          size: 17,
                          color: c.onPrimary,
                        )
                        : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedChip extends ConsumerWidget {
  const _SelectedChip({required this.uid, required this.onRemove});
  final String uid;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final p = ref.watch(profileByUidProvider(uid)).value;
    final name = p?.displayName ?? '…';
    return SizedBox(
      width: 58,
      child: Semantics(
        button: true,
        label: name,
        child: InkWell(
          onTap: onRemove,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(name: name, photoPath: p?.photoPath, size: 46),
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: c.textSecondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.background, width: 2),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                name.split(' ').first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
