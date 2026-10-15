import 'package:flutter_test/flutter_test.dart';
import 'package:hushlo/features/chat/domain/entities/chat_message.dart';
import 'package:hushlo/features/chat/domain/message_search.dart';

ChatMessage m(
  String id,
  String? text, {
  bool deleted = false,
  MessageType type = MessageType.text,
}) => ChatMessage(
  id: id,
  senderId: 'a',
  type: type,
  createdAt: DateTime(2026, 1, 1),
  status: SendStatus.sent,
  text: text,
  deleted: deleted,
);

void main() {
  final list = [
    m('1', 'Meeting at NOON'),
    m('2', 'lunch?'),
    m('3', 'moved the meeting', deleted: true),
    m('4', 'photo caption: Meeting notes', type: MessageType.image),
    m('5', null, type: MessageType.voice),
    m('6', 'Meeting', type: MessageType.system),
  ];

  test('case-insensitive substring, order preserved', () {
    expect(searchMessages(list, 'meeting').map((e) => e.id), ['1', '4']);
  });
  test('trims the query; blank returns nothing', () {
    expect(searchMessages(list, '  noon ').map((e) => e.id), ['1']);
    expect(searchMessages(list, '   '), isEmpty);
  });
  test('skips deleted, voice and system messages', () {
    expect(searchMessages(list, 'moved'), isEmpty);
  });
  test('no match', () {
    expect(searchMessages(list, 'zzz'), isEmpty);
  });
}
