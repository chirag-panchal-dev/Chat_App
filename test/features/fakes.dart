import 'dart:async';
import 'dart:io';

import 'package:hushlo/core/errors/failure.dart';
import 'package:hushlo/features/chat/domain/entities/chat_message.dart';
import 'package:hushlo/features/groups/domain/group_models.dart';
import 'package:hushlo/features/groups/domain/group_repository.dart';
import 'package:hushlo/features/chat/domain/repositories/chat_repository.dart';
import 'package:hushlo/features/conversations/domain/entities/conversation.dart';
import 'package:hushlo/features/conversations/domain/repositories/conversation_repository.dart';
import 'package:hushlo/features/profile/domain/entities/profile.dart';
import 'package:hushlo/features/profile/domain/repositories/profile_repository.dart';

ChatMessage msg(
  String id,
  DateTime at, {
  String sender = 'other',
  String text = 'hi',
  SendStatus status = SendStatus.sent,
}) => ChatMessage(
  id: id,
  senderId: sender,
  type: MessageType.text,
  createdAt: at,
  status: status,
  text: text,
);

class FakeChatRepository implements ChatRepository {
  final latest = StreamController<List<ChatMessage>>.broadcast();
  final hidden = StreamController<Set<String>>.broadcast();
  final sent = <String>[]; // message ids in send order
  final sentTexts = <String>[];
  Object? sendError;
  Completer<void>? sendGate;
  List<ChatMessage> olderPage = const [];
  MessageCursor? lastCursor;

  @override
  Stream<List<ChatMessage>> watchLatest(String c, int limit) => latest.stream;

  @override
  Future<List<ChatMessage>> loadOlder(
    String c,
    MessageCursor before,
    int limit,
  ) async {
    lastCursor = before;
    return olderPage;
  }

  @override
  Future<void> sendText({
    required String conversationId,
    required String messageId,
    required String senderId,
    required String text,
    String? replyToId,
  }) async {
    sent.add(messageId);
    sentTexts.add(text);
    if (sendGate != null) await sendGate!.future;
    final e = sendError;
    if (e != null) throw e;
  }

  @override
  Future<void> sendImage({
    required String conversationId,
    required String messageId,
    required String senderId,
    required ImagePayload image,
    String? replyToId,
  }) async {}

  @override
  Stream<Set<String>> watchHidden(String c, String uid) => hidden.stream;

  final hiddenCalls = <String>[];
  @override
  Future<void> hideMessage(String c, String uid, String mid) async =>
      hiddenCalls.add(mid);

  @override
  Stream<Map<String, Receipts>> watchAllReceipts(String c) =>
      const Stream.empty();
  @override
  Stream<Map<String, DateTime>> watchTypingAll(String c) =>
      const Stream.empty();

  final typingSet = <String>[];
  int typingCleared = 0;
  @override
  Stream<DateTime?> watchTyping(String c, String uid) => const Stream.empty();
  @override
  Future<void> setTyping(String c, String uid) async => typingSet.add(c);
  @override
  Future<void> clearTyping(String c, String uid) async => typingCleared++;

  final deletedForEveryone = <String>[];
  @override
  Future<void> deleteForEveryone(String c, String m) async =>
      deletedForEveryone.add(m);

  final delivered = <String>[];
  final readMarks = <String>[];
  @override
  Stream<Receipts> watchReceipts(String c, String uid) => const Stream.empty();
  @override
  Future<void> markDelivered(String c, String uid) async => delivered.add(c);
  @override
  Future<void> markReadReceipt(String c, String uid) async => readMarks.add(c);

  @override
  Stream<Map<String, String>> watchReactions(String c, String m) =>
      const Stream.empty();

  @override
  Future<void> setReaction(String c, String m, String uid, String? e) async {}
}

class FakeConversationRepository implements ConversationRepository {
  final reads = <String>[];
  final cleared = <String>[];
  final prefsController = StreamController<MemberPrefs>.broadcast();
  @override
  Future<void> clearChat(String id, String uid) async => cleared.add(id);
  @override
  Future<void> ensureMember(String id, String uid) async {}
  @override
  Future<void> markRead(String id, String uid) async => reads.add(id);
  @override
  Future<String> startDirect(String me, String other) async => 'x';
  @override
  Future<void> setArchived(String id, String uid, bool v) async {}
  @override
  Future<void> setMutedUntil(String id, String uid, DateTime? u) async {}
  @override
  Future<void> setPinned(String id, String uid, bool v) async {}
  @override
  Stream<Conversation?> watchConversation(String id) => const Stream.empty();
  @override
  Stream<List<Conversation>> watchConversations(String uid) =>
      const Stream.empty();
  @override
  Stream<MemberPrefs> watchMemberPrefs(String id, String uid) =>
      prefsController.stream;
}

class FakeProfileRepository implements ProfileRepository {
  final taken = <String>{};
  int availabilityChecks = 0;
  Profile? created;
  Object? createError;

  @override
  Future<bool> isUsernameAvailable(String n) async {
    availabilityChecks++;
    return !taken.contains(n);
  }

  @override
  Future<void> createProfile({
    required String uid,
    required String username,
    required String displayName,
    String? bio,
    String? photoPath,
  }) async {
    if (createError != null) throw createError!;
    created = Profile(uid: uid, username: username, displayName: displayName);
  }

  final byUsername = <String, Profile>{};
  @override
  Future<Profile?> findByUsername(String n) async => byUsername[n];
  @override
  Future<Profile?> getProfile(String uid) async => null;
  @override
  Future<String> uploadAvatar(String uid, File file) async =>
      'avatars/$uid/a.jpg';
  @override
  Future<void> updateProfile({
    required String uid,
    required String displayName,
    String? bio,
    String? photoPath,
  }) async {}
  @override
  Stream<Profile?> watchProfile(String uid) => const Stream.empty();
}

// Keep Failure import used for fakes that throw typed failures.
Failure permissionDenied() => const PermissionFailure();

// ---------------------------------------------------------------- groups
class FakeGroupRepository implements GroupRepository {
  final created = <Map<String, Object?>>[];
  final added = <Map<String, Object?>>[];
  Object? error;

  @override
  Future<String> createGroup({
    required String me,
    required String name,
    required List<String> memberUids,
    File? photo,
  }) async {
    if (error != null) throw error!;
    created.add({
      'me': me,
      'name': name,
      'members': memberUids,
      'photo': photo,
    });
    return 'g_${'a' * 32}';
  }

  @override
  Future<void> addMembers({
    required String groupId,
    required String actor,
    required List<String> uids,
  }) async {
    if (error != null) throw error!;
    added.add({'gid': groupId, 'actor': actor, 'uids': uids});
  }

  @override
  Future<void> removeMember({
    required String groupId,
    required String actor,
    required String uid,
  }) async {}
  @override
  Future<void> setAdmin({
    required String groupId,
    required String uid,
    required bool admin,
  }) async {}
  @override
  Future<void> rename({
    required String groupId,
    required String actor,
    required String name,
  }) async {}
  @override
  Future<void> setPhoto({required String groupId, required File photo}) async {}
  @override
  Future<void> leave({required String groupId, required String me}) async {}
  @override
  Stream<GroupInvite?> watchMyInvite(String groupId, String me) =>
      const Stream.empty();
  @override
  Future<GroupInvite> createInvite({
    required String groupId,
    required String me,
    required String groupName,
  }) async =>
      GroupInvite(code: 'X' * 12, groupId: groupId, groupName: groupName);
  @override
  Future<void> revokeInvite(String code) async {}
  @override
  Future<GroupInvite?> lookupInvite(String code) async => null;
  @override
  Future<void> requestJoin({required String code, required String me}) async {}
  @override
  Stream<bool> watchMyJoinRequest(String groupId, String me) =>
      const Stream.empty();
  @override
  Future<void> cancelJoinRequest({
    required String groupId,
    required String me,
  }) async {}
  @override
  Stream<List<JoinRequest>> watchJoinRequests(String groupId) =>
      const Stream.empty();
  @override
  Future<void> approveJoin({
    required String groupId,
    required String actor,
    required String uid,
  }) async {}
  @override
  Future<void> rejectJoin({
    required String groupId,
    required String uid,
  }) async {}
}
