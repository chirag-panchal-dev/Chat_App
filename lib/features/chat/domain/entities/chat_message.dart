import '../../../../core/errors/failure.dart';

enum MessageType { text, image }

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
  });

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

  /// Short description for reply quotes / previews.
  String previewText(String photoLabel) =>
      isImage
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
