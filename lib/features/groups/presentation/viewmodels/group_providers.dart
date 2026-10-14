import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/viewmodels/auth_providers.dart';
import '../../../conversations/presentation/viewmodels/conversation_providers.dart';
import '../../data/firestore_group_repository.dart';
import '../../domain/group_models.dart';
import '../../domain/group_repository.dart';

final groupRepositoryProvider = Provider<GroupRepository>(
  (ref) => FirestoreGroupRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseStorageProvider),
  ),
);

/// Uids of people you already have a one-to-one chat with (most recent
/// first): the pool you can pick group members from.
final directContactsProvider = Provider<List<String>>((ref) {
  final me = ref.watch(currentUidProvider);
  final inbox = ref.watch(inboxProvider).value;
  if (me == null || inbox == null) return const [];
  final seen = <String>{};
  final out = <String>[];
  for (final i in [...inbox.active, ...inbox.archived]) {
    final c = i.conversation;
    if (c.isGroup || c.otherDeleted(me)) continue;
    final other = c.otherUid(me);
    if (other != me && seen.add(other)) out.add(other);
  }
  return out;
});

/// The caller's own active invite code for a group (admins only).
final myInviteProvider = StreamProvider.autoDispose
    .family<GroupInvite?, String>((ref, groupId) {
      final me = ref.watch(currentUidProvider);
      if (me == null) return const Stream.empty();
      return ref.watch(groupRepositoryProvider).watchMyInvite(groupId, me);
    });

/// Pending join requests for a group (admins only).
final joinRequestsProvider = StreamProvider.autoDispose
    .family<List<JoinRequest>, String>((ref, groupId) {
      return ref.watch(groupRepositoryProvider).watchJoinRequests(groupId);
    });

/// Whether the current user has a pending request to join [groupId].
final myJoinRequestProvider = StreamProvider.autoDispose.family<bool, String>((
  ref,
  groupId,
) {
  final me = ref.watch(currentUidProvider);
  if (me == null) return const Stream.empty();
  return ref.watch(groupRepositoryProvider).watchMyJoinRequest(groupId, me);
});
