class Conversation {
  const Conversation({
    required this.id,
    required this.memberIds,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.lastSenderId,
    this.deletedAccounts = const [],
  });

  final String id;
  final List<String> memberIds;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final String? lastSenderId;
  final List<String> deletedAccounts;

  String otherUid(String me) =>
      memberIds.firstWhere((m) => m != me, orElse: () => me);

  bool otherDeleted(String me) => deletedAccounts.contains(otherUid(me));
}

/// Per-user conversation preferences (mute / pin / archive / read marker).
class MemberPrefs {
  const MemberPrefs({
    this.lastReadAt,
    this.mutedUntil,
    this.archived = false,
    this.pinned = false,
    this.clearedAt,
  });

  /// Messages at or before this time were cleared by this user (their own
  /// view only; the other participant keeps their copy).
  final DateTime? clearedAt;
  final DateTime? lastReadAt;
  final DateTime? mutedUntil;
  final bool archived;
  final bool pinned;

  bool isMuted([DateTime? now]) =>
      mutedUntil != null && mutedUntil!.isAfter(now ?? DateTime.now());
}

/// One row of the inbox: conversation + the viewer's own preferences + the
/// newest message (read directly, so the row works without server summaries).
class InboxItem {
  const InboxItem(
    this.conversation,
    this.prefs, {
    required this.me,
    this.lastMessage,
  });
  final Conversation conversation;
  final MemberPrefs prefs;
  final String me;
  final InboxLastMessage? lastMessage;

  /// True when everything in this conversation was cleared by this user.
  bool get isCleared => _cleared(lastMessage?.at ?? conversation.lastMessageAt);

  bool _cleared(DateTime? at) =>
      at != null && prefs.clearedAt != null && !at.isAfter(prefs.clearedAt!);

  /// Newest activity, ignoring anything this user has cleared.
  DateTime? get lastActivity {
    final at = lastMessage?.at ?? conversation.lastMessageAt;
    return _cleared(at) ? null : at;
  }

  String? get preview =>
      _cleared(lastMessage?.at ?? conversation.lastMessageAt)
          ? null
          : (lastMessage?.preview ?? conversation.lastMessagePreview);
  String? get lastSenderId =>
      lastMessage?.senderId ?? conversation.lastSenderId;
  bool get lastIsMine => lastSenderId == me;

  bool get unread {
    final at = lastActivity;
    if (at == null || lastSenderId == me) return false;
    final read = prefs.lastReadAt;
    return read == null || at.isAfter(read);
  }
}

/// Plain summary of a conversation's newest message for the inbox.
class InboxLastMessage {
  const InboxLastMessage({
    required this.at,
    required this.senderId,
    required this.preview,
    required this.isImage,
    this.pending = false,
    this.deleted = false,
  });
  final bool deleted;
  final DateTime at;
  final String senderId;
  final String preview; // text, or caption, or '' for an uncaptioned photo
  final bool isImage;
  final bool pending;
}

/// Sorts pinned first, then newest activity.
List<InboxItem> sortInbox(Iterable<InboxItem> items) {
  final list = items.toList();
  list.sort((a, b) {
    if (a.prefs.pinned != b.prefs.pinned) return a.prefs.pinned ? -1 : 1;
    final ta = a.lastActivity;
    final tb = b.lastActivity;
    if (ta == null && tb == null) return 0;
    if (ta == null) return 1;
    if (tb == null) return -1;
    return tb.compareTo(ta);
  });
  return list;
}
