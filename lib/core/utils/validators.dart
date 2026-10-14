import '../config/app_config.dart';
import '../errors/failure.dart';

abstract final class Usernames {
  static final _pattern = RegExp(r'^[a-z0-9_]{3,20}$');
  static const _reserved = {
    'admin',
    'administrator',
    'support',
    'hushlo',
    'help',
    'moderator',
    'official',
    'system',
    'root',
    'null',
    'undefined',
  };

  /// Trims, strips a leading '@' and lower-cases.
  static String normalize(String input) {
    var v = input.trim().toLowerCase();
    if (v.startsWith('@')) v = v.substring(1);
    return v;
  }

  static bool isValid(String normalized) =>
      _pattern.hasMatch(normalized) && !_reserved.contains(normalized);

  /// Throws [ValidationFailure] when invalid.
  static String require(String input) {
    final n = normalize(input);
    if (!isValid(n)) {
      throw const ValidationFailure(ValidationReason.usernameInvalid);
    }
    return n;
  }
}

abstract final class ConversationIds {
  /// Stable ID for a direct chat: the two UIDs sorted and joined, so both
  /// participants always derive the same document.
  static String direct(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  static List<String> sortedMembers(String a, String b) => [a, b]..sort();
}

abstract final class FieldValidators {
  static bool isEmail(String v) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(v.trim());

  static bool isValidDisplayName(String v) {
    final t = v.trim();
    return t.isNotEmpty && t.length <= AppConfig.maxDisplayNameLength;
  }

  /// Returns the trimmed message text or throws a [ValidationFailure].
  static String messageText(String raw, {int? max}) {
    final t = raw.trim();
    if (t.isEmpty) throw const ValidationFailure(ValidationReason.messageEmpty);
    if (t.length > (max ?? AppConfig.maxMessageLength)) {
      throw const ValidationFailure(ValidationReason.messageTooLong);
    }
    return t;
  }
}
