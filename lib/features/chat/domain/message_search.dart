import 'entities/chat_message.dart';

/// Messages (newest first, as given) whose text or photo caption contains
/// [query], ignoring case and surrounding spaces. Deleted messages, system
/// notices and voice notes have no searchable text.
List<ChatMessage> searchMessages(Iterable<ChatMessage> messages, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  return [
    for (final m in messages)
      if (!m.deleted &&
          !m.isSystem &&
          !m.isVoice &&
          (m.text ?? '').toLowerCase().contains(q))
        m,
  ];
}
