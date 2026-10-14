import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/viewmodels/auth_providers.dart';
import '../../../chat/domain/entities/chat_message.dart';
import '../../../chat/presentation/viewmodels/chat_providers.dart';
import '../../data/firestore_conversation_repository.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/conversation_repository.dart';

final conversationRepositoryProvider = Provider<ConversationRepository>(
  (ref) => FirestoreConversationRepository(ref.watch(firestoreProvider)),
);

final _conversationsProvider = StreamProvider<List<Conversation>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(conversationRepositoryProvider).watchConversations(uid);
});

final memberPrefsProvider = StreamProvider.family<MemberPrefs, String>((
  ref,
  conversationId,
) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const Stream.empty();
  return ref
      .watch(conversationRepositoryProvider)
      .watchMemberPrefs(conversationId, uid);
});

final conversationProvider = StreamProvider.family<Conversation?, String>(
  (ref, id) => ref.watch(conversationRepositoryProvider).watchConversation(id),
);

class Inbox {
  const Inbox({required this.active, required this.archived});
  final List<InboxItem> active;
  final List<InboxItem> archived;
}

/// Conversations joined with the user's own prefs, split into active/archived
/// and sorted (pinned first). Conversations whose summary hasn't been written
/// yet (no Cloud Function deployed, or no messages) still appear, without a
/// preview.
final inboxProvider = Provider<AsyncValue<Inbox>>((ref) {
  final me = ref.watch(currentUidProvider);
  final convs = ref.watch(_conversationsProvider);
  if (me == null) return const AsyncValue.loading();
  return convs.whenData((list) {
    final items = <InboxItem>[];
    for (final c in list) {
      final prefs =
          ref.watch(memberPrefsProvider(c.id)).value ?? const MemberPrefs();
      final m = ref.watch(latestMessageProvider(c.id)).value;
      items.add(
        InboxItem(
          c,
          prefs,
          me: me,
          lastMessage:
              m == null
                  ? null
                  : InboxLastMessage(
                    at: m.createdAt,
                    senderId: m.senderId,
                    preview: m.isImage ? (m.text ?? '') : (m.text ?? ''),
                    isImage: m.isImage,
                    pending: m.status == SendStatus.sending,
                    deleted: m.deleted,
                  ),
        ),
      );
    }
    final sorted = sortInbox(items);
    return Inbox(
      active: sorted.where((i) => !i.prefs.archived).toList(),
      archived: sorted.where((i) => i.prefs.archived).toList(),
    );
  });
});
