/// A private note in "Saved messages": typed by the user, or copied from a
/// chat (then [sourceName] says whose message it was).
class SavedNote {
  const SavedNote({
    required this.id,
    required this.text,
    required this.createdAt,
    this.sourceName,
    this.pending = false,
  });

  final String id;
  final String text;
  final DateTime createdAt;
  final String? sourceName;

  /// Not yet acknowledged by the server (offline / just added).
  final bool pending;
}

const maxSavedNoteLength = 4000;

/// Trimmed note text, or null when it is empty / too long.
String? cleanNoteText(String raw) {
  final t = raw.trim();
  if (t.isEmpty || t.length > maxSavedNoteLength) return null;
  return t;
}
