import 'package:flutter_test/flutter_test.dart';
import 'package:hushlo/core/errors/failure.dart';
import 'package:hushlo/core/utils/validators.dart';

void main() {
  group('Usernames', () {
    test('normalizes case, whitespace and leading @', () {
      expect(Usernames.normalize('  @Sam_User '), 'sam_user');
    });
    test('accepts valid names', () {
      expect(Usernames.isValid('sam_user'), isTrue);
      expect(Usernames.isValid('abc'), isTrue);
      expect(Usernames.isValid('a' * 20), isTrue);
    });
    test('rejects invalid, too short/long and reserved names', () {
      for (final bad in [
        'ab',
        'a' * 21,
        'has space',
        'dash-name',
        'Üser',
        'admin',
        '',
      ]) {
        expect(Usernames.isValid(bad), isFalse, reason: bad);
      }
    });
    test('require throws ValidationFailure', () {
      expect(() => Usernames.require('x'), throwsA(isA<ValidationFailure>()));
      expect(Usernames.require(' @Hello_1 '), 'hello_1');
    });
  });

  group('ConversationIds', () {
    test('is symmetric so a pair never gets two chats', () {
      expect(
        ConversationIds.direct('b', 'a'),
        ConversationIds.direct('a', 'b'),
      );
      expect(ConversationIds.direct('uidB', 'uidA'), 'uidA_uidB');
    });
    test('sortedMembers is sorted', () {
      expect(ConversationIds.sortedMembers('z', 'a'), ['a', 'z']);
    });
  });

  group('FieldValidators', () {
    test('messageText trims and rejects blank/oversized', () {
      expect(FieldValidators.messageText('  hi  '), 'hi');
      expect(
        () => FieldValidators.messageText('   '),
        throwsA(isA<ValidationFailure>()),
      );
      expect(
        () => FieldValidators.messageText('a' * 4001),
        throwsA(isA<ValidationFailure>()),
      );
      expect(FieldValidators.messageText('a' * 4000).length, 4000);
    });
    test('email check', () {
      expect(FieldValidators.isEmail('a@b.co'), isTrue);
      expect(FieldValidators.isEmail('nope'), isFalse);
    });
  });
}
