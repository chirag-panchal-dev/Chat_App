import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/firestore_chat_repository.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/send_text_message_use_case.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => FirestoreChatRepository(ref.watch(firestoreProvider)),
);

final sendTextUseCaseProvider = Provider<SendTextMessageUseCase>(
  (ref) => SendTextMessageUseCase(ref.watch(chatRepositoryProvider)),
);

/// Newest message of a conversation (one document). This is what the inbox
/// uses for the preview, time and unread state, so the list works without
/// any server-side summary.
final latestMessageProvider = StreamProvider.family<ChatMessage?, String>((
  ref,
  conversationId,
) {
  return ref
      .watch(chatRepositoryProvider)
      .watchLatest(conversationId, 1)
      .map((l) => l.isEmpty ? null : l.first);
});

/// The other participant's receipts for a conversation.
final peerReceiptsProvider = StreamProvider.autoDispose
    .family<Receipts, ({String cid, String peer})>((ref, k) {
      return ref.watch(chatRepositoryProvider).watchReceipts(k.cid, k.peer);
    });

/// How long after the last signal a person still counts as "typing".
const typingWindow = Duration(seconds: 6);

bool isTypingNow(DateTime? receivedAt, [DateTime? now]) =>
    receivedAt != null &&
    (now ?? DateTime.now()).difference(receivedAt) < typingWindow;

/// The other participant's typing signal (local receipt time, null = not typing).
final peerTypingProvider = StreamProvider.autoDispose
    .family<DateTime?, ({String cid, String peer})>((ref, k) {
      return ref.watch(chatRepositoryProvider).watchTyping(k.cid, k.peer);
    });

/// Ticks every 2s; watched only while someone is typing, so it expires the
/// indicator without a permanent timer.
final typingClockProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 2), (_) => DateTime.now());
});
