import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/viewmodels/auth_providers.dart';
import '../../../conversations/presentation/viewmodels/conversation_providers.dart';
import '../../../privacy_settings/presentation/viewmodels/settings_providers.dart';
import 'chat_providers.dart';

/// Marks incoming messages as *delivered* as soon as this device has received
/// them (the inbox listens to every conversation's newest message). It only
/// writes for unread incoming messages, once per message per session.
///
/// Limitation (documented): delivery is recorded when the app is running; a
/// message received only as a background push is marked delivered the next
/// time the app opens.
class DeliveryReceiptsController extends Notifier<void> {
  final _acked =
      <String, DateTime>{}; // conversationId -> last acked message time

  @override
  void build() {
    final me = ref.watch(currentUidProvider);
    if (me == null) return;
    ref.listen(inboxProvider, (_, next) {
      final inbox = next.value;
      if (inbox == null) return;
      final shareRead =
          ref.read(settingsProvider).value?.readReceiptsEnabled ?? true;
      for (final item in [...inbox.active, ...inbox.archived]) {
        final m = item.lastMessage;
        if (m == null || m.pending || m.senderId == me) continue;
        final id = item.conversation.id;
        final prev = _acked[id];
        if (prev != null && !m.at.isAfter(prev)) continue;
        _acked[id] = m.at;
        final repo = ref.read(chatRepositoryProvider);
        // Unread: we only know it reached this device -> delivered.
        // Already read on this account: catch the sender up with a read tick.
        final write =
            (!item.unread && shareRead)
                ? repo.markReadReceipt(id, me)
                : repo.markDelivered(id, me);
        write.catchError((Object _) {});
      }
    }, fireImmediately: true);
  }
}

final deliveryReceiptsProvider =
    NotifierProvider<DeliveryReceiptsController, void>(
      DeliveryReceiptsController.new,
    );
