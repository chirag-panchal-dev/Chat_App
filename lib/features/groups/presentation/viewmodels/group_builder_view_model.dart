import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/validators.dart';
import '../../../attachments/presentation/viewmodels/attachment_providers.dart';
import '../../../auth/presentation/viewmodels/auth_providers.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../../profile/presentation/viewmodels/profile_providers.dart';
import '../../domain/group_rules.dart';
import 'group_providers.dart';

class GroupBuilderState {
  const GroupBuilderState({
    this.selected = const [],
    this.found = const {},
    this.photo,
    this.busy = false,
    this.failure,
    this.lookupBusy = false,
    this.notice,
  });

  /// Selected uids in the order they were picked.
  final List<String> selected;

  /// Profiles found by exact username (not in your chats).
  final Map<String, Profile> found;
  final File? photo;
  final bool busy;
  final bool lookupBusy;
  final Failure? failure;

  /// Transient hint: 'full' | 'notFound' | 'self' | 'already'.
  final String? notice;

  GroupBuilderState copyWith({
    List<String>? selected,
    Map<String, Profile>? found,
    Object? photo = _keep,
    bool? busy,
    bool? lookupBusy,
    Object? failure = _keep,
    Object? notice = _keep,
  }) => GroupBuilderState(
    selected: selected ?? this.selected,
    found: found ?? this.found,
    photo: identical(photo, _keep) ? this.photo : photo as File?,
    busy: busy ?? this.busy,
    lookupBusy: lookupBusy ?? this.lookupBusy,
    failure: identical(failure, _keep) ? this.failure : failure as Failure?,
    notice: identical(notice, _keep) ? this.notice : notice as String?,
  );

  static const _keep = Object();
}

/// Selection logic shared by "New group" and "Add members".
/// [capacity] = how many people can still be picked (19 for a new group,
/// remaining slots when adding to an existing one).
class GroupBuilderViewModel extends Notifier<GroupBuilderState> {
  GroupBuilderViewModel(this.capacity);
  final int capacity;

  @override
  GroupBuilderState build() => const GroupBuilderState();

  bool get isFull => state.selected.length >= capacity;

  void toggle(String uid) {
    final sel = [...state.selected];
    if (sel.remove(uid)) {
      state = state.copyWith(selected: sel, notice: null);
      return;
    }
    if (isFull) {
      state = state.copyWith(notice: 'full');
      return;
    }
    state = state.copyWith(selected: [...sel, uid], notice: null);
  }

  /// Exact-username lookup for someone you haven't chatted with yet.
  Future<void> addByUsername(
    String raw, {
    Set<String> exclude = const {},
  }) async {
    final name = Usernames.normalize(raw);
    if (!Usernames.isValid(name)) {
      state = state.copyWith(notice: 'notFound');
      return;
    }
    state = state.copyWith(lookupBusy: true, notice: null);
    try {
      final p = await ref.read(profileRepositoryProvider).findByUsername(name);
      final me = ref.read(currentUidProvider);
      if (p == null) {
        state = state.copyWith(lookupBusy: false, notice: 'notFound');
      } else if (p.uid == me) {
        state = state.copyWith(lookupBusy: false, notice: 'self');
      } else if (exclude.contains(p.uid)) {
        state = state.copyWith(lookupBusy: false, notice: 'already');
      } else if (state.selected.contains(p.uid)) {
        state = state.copyWith(lookupBusy: false, notice: 'already');
      } else if (isFull) {
        state = state.copyWith(lookupBusy: false, notice: 'full');
      } else {
        state = state.copyWith(
          lookupBusy: false,
          found: {...state.found, p.uid: p},
          selected: [...state.selected, p.uid],
        );
      }
    } catch (e) {
      state = state.copyWith(lookupBusy: false, failure: Failure.from(e));
    }
  }

  void setPhoto(File? f) => state = state.copyWith(photo: f);

  /// Creates the group; returns its id or null on failure.
  Future<String?> create(String name) async {
    final me = ref.read(currentUidProvider);
    if (me == null || state.busy) return null;
    if (!GroupRules.isValidName(name) || state.selected.isEmpty) return null;
    state = state.copyWith(busy: true, failure: null);
    try {
      File? photo;
      final raw = state.photo;
      if (raw != null) {
        photo = await ref.read(imageProcessorProvider).processAvatar(raw);
      }
      final id = await ref
          .read(groupRepositoryProvider)
          .createGroup(
            me: me,
            name: name,
            memberUids: state.selected,
            photo: photo,
          );
      state = state.copyWith(busy: false);
      return id;
    } catch (e) {
      state = state.copyWith(busy: false, failure: Failure.from(e));
      return null;
    }
  }

  /// Adds the selected people to an existing group.
  Future<bool> addTo(String groupId) async {
    final me = ref.read(currentUidProvider);
    if (me == null || state.busy || state.selected.isEmpty) return false;
    state = state.copyWith(busy: true, failure: null);
    try {
      await ref
          .read(groupRepositoryProvider)
          .addMembers(groupId: groupId, actor: me, uids: state.selected);
      state = state.copyWith(busy: false);
      return true;
    } catch (e) {
      state = state.copyWith(busy: false, failure: Failure.from(e));
      return false;
    }
  }
}

final groupBuilderProvider = NotifierProvider.autoDispose
    .family<GroupBuilderViewModel, GroupBuilderState, int>(
      GroupBuilderViewModel.new,
    );
