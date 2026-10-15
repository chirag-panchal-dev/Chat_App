import '../../../../core/errors/failure.dart';

enum MessageType { text, image, voice, file, video, system }

/// Group membership/name events rendered as centred notices in a group chat.
enum GroupEvent { added, removed, left, renamed, timer }

/// sending -> sent (stored on the server) -> delivered (the recipient's app
/// has received it) -> read (the recipient opened the chat, and has read
/// receipts enabled).
enum SendStatus { sending, sent, delivered, read, failed }

/// The other participant's acknowledgements for this conversation.
class Receipts {
  const Receipts({this.lastDeliveredAt, this.lastReadAt});
  final DateTime? lastDeliveredAt;
  final DateTime? lastReadAt;
}

/// Status of one of *my* messages given the recipient's receipts.
SendStatus resolveStatus(ChatMessage m, Receipts? r) {
  if (m.status == SendStatus.sending || m.status == SendStatus.failed) {
    return m.status;
  }
  final read = r?.lastReadAt;
  if (read != null && !read.isBefore(m.createdAt)) return SendStatus.read;
  final delivered = r?.lastDeliveredAt;
  if (delivered != null && !delivered.isBefore(m.createdAt)) {
    return SendStatus.delivered;
  }
  return SendStatus.sent;
}

/// Status of one of *my* messages in a group: delivered only when **every**
/// other member has received it, read only when every other member has read it.
SendStatus resolveGroupStatus(
  ChatMessage m,
  Map<String, Receipts> receiptsByUid,
  Iterable<String> others,
) {
  if (m.status == SendStatus.sending || m.status == SendStatus.failed) {
    return m.status;
  }
  final list = others.toList();
  if (list.isEmpty) return SendStatus.sent;
  var allDelivered = true;
  var allRead = true;
  for (final uid in list) {
    final s = resolveStatus(m, receiptsByUid[uid]);
    if (s != SendStatus.read) allRead = false;
    if (s != SendStatus.read && s != SendStatus.delivered) allDelivered = false;
  }
  if (allRead) return SendStatus.read;
  if (allDelivered) return SendStatus.delivered;
  return SendStatus.sent;
}

/// Per-member status of one of my messages (for the "Message info" screen).
SendStatus memberStatus(ChatMessage m, Receipts? r) => resolveStatus(m, r);

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.type,
    required this.createdAt,
    required this.status,
    this.text,
    this.mediaPath,
    this.thumbnailPath,
    this.width,
    this.height,
    this.replyToId,
    this.deleted = false,
    this.event,
    this.targetUid,
    this.durationMs,
    this.waveform,
    this.expiresAt,
    this.timerSec,
    this.editedAt,
    this.fileName,
    this.mimeType,
    this.sizeBytes,
    this.pageCount,
  });

  /// PDFs: number of pages (shown under the file name).
  final int? pageCount;

  /// Documents: the original file name; documents and videos: type and size.
  final String? fileName;
  final String? mimeType;
  final int? sizeBytes;

  /// Set when the sender edited the text (shown as "Edited").
  final DateTime? editedAt;
  bool get edited => editedAt != null;

  /// The sender may edit a sent text message for 15 minutes (matches rules).
  static const editWindow = Duration(minutes: 15);
  bool canEdit(String me, [DateTime? now]) =>
      senderId == me &&
      type == MessageType.text &&
      !deleted &&
      status != SendStatus.sending &&
      status != SendStatus.failed &&
      (now ?? DateTime.now()).difference(createdAt) < editWindow;

  /// Disappearing messages: when this message goes away (null = never).
  final DateTime? expiresAt;

  /// For `GroupEvent.timer` notices: the new timer in seconds (0 = off).
  final int? timerSec;

  /// Past its expiry. A server TTL policy deletes the document eventually
  /// (can lag by a day), so clients hide it from this moment.
  bool isExpired([DateTime? now]) =>
      expiresAt != null && !expiresAt!.isAfter(now ?? DateTime.now());

  /// Voice notes: length and bar heights (0..100) for the waveform.
  final int? durationMs;
  final List<int>? waveform;

  /// Set for `MessageType.system` messages.
  final GroupEvent? event;
  final String? targetUid;

  bool get isSystem => type == MessageType.system;

  final String id;
  final String senderId;
  final MessageType type;
  final DateTime createdAt;
  final SendStatus status;
  final String? text;
  final String? mediaPath;
  final String? thumbnailPath;
  final int? width;
  final int? height;
  final String? replyToId;

  /// Deleted for everyone by the sender (content wiped, tombstone shown).
  final bool deleted;

  /// The sender can still delete this for everyone (48h window, matches rules).
  bool canDeleteForEveryone(String me, [DateTime? now]) =>
      senderId == me &&
      !deleted &&
      status != SendStatus.sending &&
      (now ?? DateTime.now()).difference(createdAt) < const Duration(hours: 48);

  bool get isImage => type == MessageType.image;
  bool get isVoice => type == MessageType.voice;
  bool get isFile => type == MessageType.file;
  bool get isVideo => type == MessageType.video;

  /// Short description for reply quotes / previews.
  String previewText(
    String photoLabel, {
    String? voiceLabel,
    String? videoLabel,
    String? fileLabel,
  }) =>
      isSystem
          ? ''
          : isVoice
          ? (voiceLabel ?? 'Voice message')
          : isVideo
          ? (videoLabel ?? 'Video')
          : isFile
          ? (fileName ?? fileLabel ?? 'Document')
          : isImage
          ? ((text?.isNotEmpty ?? false) ? text! : photoLabel)
          : (text ?? '');
}

/// A text message the server rejected or that could not be sent; kept locally
/// so the user can retry or discard instead of losing it.
class FailedMessage {
  const FailedMessage({
    required this.id,
    required this.text,
    required this.failure,
    this.replyToId,
    required this.createdAt,
  });

  final String id;
  final String text;
  final String? replyToId;
  final Failure failure;
  final DateTime createdAt;
}

/// Position of the oldest loaded message, used to fetch the next older page.
class MessageCursor {
  const MessageCursor(this.createdAt, this.id);
  final DateTime createdAt;
  final String id;
}
