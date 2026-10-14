import 'package:flutter_test/flutter_test.dart';
import 'package:hushlo/features/chat/domain/entities/chat_message.dart';
import 'package:hushlo/features/conversations/domain/entities/conversation.dart';

ChatMessage mine(DateTime at, {SendStatus s = SendStatus.sent}) => ChatMessage(
  id: 'm',
  senderId: 'me',
  type: MessageType.text,
  createdAt: at,
  status: s,
  text: 'x',
);

void main() {
  final t0 = DateTime(2026, 1, 1, 10);

  group('resolveStatus (WhatsApp-style ticks)', () {
    test('pending stays sending regardless of receipts', () {
      expect(
        resolveStatus(
          mine(t0, s: SendStatus.sending),
          Receipts(lastReadAt: t0),
        ),
        SendStatus.sending,
      );
    });
    test('no receipts -> sent (one tick)', () {
      expect(resolveStatus(mine(t0), null), SendStatus.sent);
      expect(resolveStatus(mine(t0), const Receipts()), SendStatus.sent);
    });
    test('delivered after recipient device acknowledged', () {
      final r = Receipts(lastDeliveredAt: t0.add(const Duration(seconds: 2)));
      expect(resolveStatus(mine(t0), r), SendStatus.delivered);
    });
    test('read beats delivered', () {
      final r = Receipts(
        lastDeliveredAt: t0.add(const Duration(seconds: 1)),
        lastReadAt: t0.add(const Duration(seconds: 5)),
      );
      expect(resolveStatus(mine(t0), r), SendStatus.read);
    });
    test('receipts older than the message do not apply', () {
      final r = Receipts(
        lastDeliveredAt: t0.subtract(const Duration(minutes: 1)),
        lastReadAt: t0.subtract(const Duration(minutes: 1)),
      );
      expect(resolveStatus(mine(t0), r), SendStatus.sent);
    });
    test('a new message after the last read is not read', () {
      final r = Receipts(lastReadAt: t0);
      expect(
        resolveStatus(mine(t0.add(const Duration(minutes: 3))), r),
        SendStatus.sent,
      );
    });
  });

  group('inbox without server summaries', () {
    Conversation conv() => const Conversation(id: 'a_b', memberIds: ['a', 'b']);
    test('preview, time and unread come from the newest message', () {
      final item = InboxItem(
        conv(),
        const MemberPrefs(),
        me: 'a',
        lastMessage: InboxLastMessage(
          at: t0,
          senderId: 'b',
          preview: 'hello',
          isImage: false,
        ),
      );
      expect(item.preview, 'hello');
      expect(item.lastActivity, t0);
      expect(item.unread, isTrue);
      expect(item.lastIsMine, isFalse);
    });
    test('own last message is never unread', () {
      final item = InboxItem(
        conv(),
        const MemberPrefs(),
        me: 'a',
        lastMessage: InboxLastMessage(
          at: t0,
          senderId: 'a',
          preview: 'yo',
          isImage: false,
        ),
      );
      expect(item.unread, isFalse);
      expect(item.lastIsMine, isTrue);
    });
    test('sorted by real last message time even when summary is null', () {
      InboxItem it(String id, DateTime at) => InboxItem(
        Conversation(id: id, memberIds: const ['a', 'b']),
        const MemberPrefs(),
        me: 'a',
        lastMessage: InboxLastMessage(
          at: at,
          senderId: 'b',
          preview: '',
          isImage: false,
        ),
      );
      final sorted = sortInbox([
        it('old', t0),
        it('new', t0.add(const Duration(days: 1))),
      ]);
      expect(sorted.map((i) => i.conversation.id), ['new', 'old']);
    });
  });

  group('cleared chat in the inbox', () {
    Conversation conv() => const Conversation(id: 'a_b', memberIds: ['a', 'b']);
    InboxItem item(DateTime msgAt, DateTime? clearedAt) => InboxItem(
      conv(),
      MemberPrefs(clearedAt: clearedAt),
      me: 'a',
      lastMessage: InboxLastMessage(
        at: msgAt,
        senderId: 'b',
        preview: 'hi',
        isImage: false,
      ),
    );

    test('a cleared conversation shows no preview, time or unread', () {
      final i = item(DateTime(2026, 1, 1), DateTime(2026, 1, 2));
      expect(i.isCleared, isTrue);
      expect(i.preview, isNull);
      expect(i.lastActivity, isNull);
      expect(i.unread, isFalse);
    });
    test('a message after the clear time shows normally', () {
      final i = item(DateTime(2026, 1, 3), DateTime(2026, 1, 2));
      expect(i.isCleared, isFalse);
      expect(i.preview, 'hi');
      expect(i.unread, isTrue);
    });
  });
}
