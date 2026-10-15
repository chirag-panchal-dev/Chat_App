import 'saved_note.dart';

abstract interface class SavedRepository {
  /// Newest notes first (bounded).
  Stream<List<SavedNote>> watch(String uid);

  /// Adds a note; [sourceName] marks a message copied from a chat.
  Future<void> add(String uid, String text, {String? sourceName});

  Future<void> delete(String uid, String noteId);
}
