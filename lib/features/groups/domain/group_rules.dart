import 'dart:math';

import '../../conversations/domain/entities/conversation.dart';
import 'group_models.dart';

/// Pure group policy helpers (mirrors the security rules; unit-tested).
abstract final class GroupRules {
  static const maxNameLength = 50;

  /// How many more people can still be added.
  static int remainingSlots(int currentMembers) =>
      (maxGroupMembers - currentMembers).clamp(0, maxGroupMembers);

  static bool canAdd(int currentMembers, int adding) =>
      adding > 0 && currentMembers + adding <= maxGroupMembers;

  static bool isValidName(String name) {
    final t = name.trim();
    return t.isNotEmpty && t.length <= maxNameLength;
  }

  /// Computes the new member/admin lists when [me] leaves. If [me] was the
  /// last admin and others remain, the first remaining member is promoted so a
  /// group is never left without an admin.
  static LeavePlan planLeave({
    required List<String> members,
    required List<String> admins,
    required String me,
  }) {
    final remaining = members.where((m) => m != me).toList();
    var nextAdmins =
        admins.where((a) => a != me && remaining.contains(a)).toList();
    if (nextAdmins.isEmpty && remaining.isNotEmpty) {
      nextAdmins = [remaining.first];
    }
    return LeavePlan(memberIds: remaining, adminIds: nextAdmins);
  }

  /// Whether [uid] may be removed/demoted: the last admin cannot be.
  static bool isLastAdmin(List<String> admins, String uid) =>
      admins.length == 1 && admins.first == uid;

  static const _alphabet =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';

  /// Random invite code (12 chars, no look-alike characters), matches the
  /// rules' `^[A-Za-z0-9]{10,24}$`.
  static String generateInviteCode([Random? random, int length = 12]) {
    final r = random ?? Random.secure();
    return List.generate(
      length,
      (_) => _alphabet[r.nextInt(_alphabet.length)],
    ).join();
  }

  /// Normalises user input (trims spaces; codes are case-sensitive).
  static String? normalizeInviteCode(String input) {
    final t = input.trim().replaceAll(RegExp(r'\s+'), '');
    return RegExp(r'^[A-Za-z0-9]{10,24}$').hasMatch(t) ? t : null;
  }

  /// Extracts a code from pasted text such as "Join my group on Hushlo — code: ABC…".
  static String? extractInviteCode(String text) {
    for (final m in RegExp(r'[A-Za-z0-9]{10,24}').allMatches(text)) {
      final c = normalizeInviteCode(m.group(0)!);
      if (c != null) return c;
    }
    return null;
  }
}
