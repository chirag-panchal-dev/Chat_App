import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hushlo/features/auth/presentation/viewmodels/auth_providers.dart';
import 'package:hushlo/features/saved/domain/saved_note.dart';
import 'package:hushlo/features/saved/domain/saved_repository.dart';
import 'package:hushlo/features/saved/presentation/screens/saved_messages_screen.dart';
import 'package:hushlo/features/saved/presentation/viewmodels/saved_providers.dart';

import '../helpers/pump_app.dart';

class FakeSavedRepository implements SavedRepository {
  final _ctl = StreamController<List<SavedNote>>.broadcast();
  final notes = <SavedNote>[];
  Object? addError;
  var _n = 0;

  void _emit() => _ctl.add(List.of(notes.reversed));

  @override
  Stream<List<SavedNote>> watch(String uid) async* {
    yield List.of(notes.reversed);
    yield* _ctl.stream;
  }

  @override
  Future<void> add(String uid, String text, {String? sourceName}) async {
    if (addError != null) throw addError!;
    notes.add(
      SavedNote(
        id: 'n${_n++}',
        text: text,
        createdAt: DateTime.now(),
        sourceName: sourceName,
      ),
    );
    _emit();
  }

  @override
  Future<void> delete(String uid, String noteId) async {
    notes.removeWhere((n) => n.id == noteId);
    _emit();
  }
}

void main() {
  test('cleanNoteText trims and rejects empty / oversized text', () {
    expect(cleanNoteText('  hi  '), 'hi');
    expect(cleanNoteText('   '), isNull);
    expect(cleanNoteText(''), isNull);
    expect(cleanNoteText('a' * maxSavedNoteLength), isNotNull);
    expect(cleanNoteText('a' * (maxSavedNoteLength + 1)), isNull);
  });

  group('SavedMessagesScreen', () {
    late FakeSavedRepository repo;
    setUp(() => repo = FakeSavedRepository());

    Future<void> open(WidgetTester t) async {
      await t.pumpApp(
        const SavedMessagesScreen(),
        overrides: [
          currentUidProvider.overrideWithValue('me'),
          savedRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await t.pump();
      await t.pump();
    }

    testWidgets('empty state, then adding a note shows it', (t) async {
      await open(t);
      expect(find.text('Nothing saved yet'), findsOneWidget);
      expect(
        t
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.bookmark_add_rounded),
            )
            .onPressed,
        isNull,
      );
      await t.enterText(find.byType(TextField), '  buy milk  ');
      await t.pump();
      await t.tap(find.byTooltip('Save note'));
      await t.pump();
      await t.pump();
      expect(repo.notes.single.text, 'buy milk');
      expect(find.text('buy milk'), findsOneWidget);
      expect(find.text('Nothing saved yet'), findsNothing);
      expect(t.widget<TextField>(find.byType(TextField)).controller!.text, '');
    });

    testWidgets('a failed save keeps the typed text', (t) async {
      repo.addError = Exception('offline');
      await open(t);
      await t.enterText(find.byType(TextField), 'keep me');
      await t.pump();
      await t.tap(find.byTooltip('Save note'));
      await t.pump();
      await t.pump();
      expect(find.text("Couldn't save. Please try again."), findsOneWidget);
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        'keep me',
      );
    });

    testWidgets('notes copied from a chat show where they came from', (
      t,
    ) async {
      repo.notes.add(
        SavedNote(
          id: 'a',
          text: 'the wifi password',
          createdAt: DateTime.now(),
          sourceName: 'Aarav',
        ),
      );
      await open(t);
      expect(find.text('the wifi password'), findsOneWidget);
      expect(find.text('From Aarav'), findsOneWidget);
    });

    testWidgets('long-press offers delete', (t) async {
      repo.notes.add(
        SavedNote(id: 'a', text: 'temp note', createdAt: DateTime.now()),
      );
      await open(t);
      await t.longPress(find.text('temp note'));
      await t.pumpAndSettle();
      await t.tap(find.text('Delete note'));
      await t.pumpAndSettle();
      expect(repo.notes, isEmpty);
      expect(find.text('temp note'), findsNothing);
    });
  });
}
