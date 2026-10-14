import '../../conversations/domain/repositories/conversation_repository.dart';

/// Creates (or finds) the single stable direct conversation for a pair.
class StartDirectConversationUseCase {
  const StartDirectConversationUseCase(this._conversations);
  final ConversationRepository _conversations;

  Future<String> call({required String me, required String otherUid}) =>
      _conversations.startDirect(me, otherUid);
}
