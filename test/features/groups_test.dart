import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hushlo/features/auth/presentation/viewmodels/auth_providers.dart';
import 'package:hushlo/features/chat/domain/entities/chat_message.dart';
import 'package:hushlo/features/chat/presentation/viewmodels/chat_providers.dart';
import 'package:hushlo/features/conversations/domain/entities/conversation.dart';
import 'package:hushlo/features/groups/domain/group_rules.dart';
import 'package:hushlo/features/groups/presentation/viewmodels/group_builder_view_model.dart';
import 'package:hushlo/features/groups/presentation/viewmodels/group_providers.dart';
import 'package:hushlo/features/profile/domain/entities/profile.dart';
import 'package:hushlo/features/profile/presentation/viewmodels/profile_providers.dart';

import 'fakes.dart';

void main() {
  group('GroupRules (mirrors the security rules)', () {
    test('max 20 members, slots and canAdd', () {
      expect(maxGroupMembers, 20);
      expect(GroupRules.remainingSlots(5), 15);
      expect(GroupRules.remainingSlots(20), 0);
      expect(GroupRules.remainingSlots(25), 0);
      expect(GroupRules.canAdd(19, 1), isTrue);
      expect(GroupRules.canAdd(19, 2), isFalse);
      expect(GroupRules.canAdd(5, 0), isFalse);
    });

    test('name validation (1..50 trimmed)', () {
      expect(GroupRules.isValidName('  Friends  '), isTrue);
      expect(GroupRules.isValidName('   '), isFalse);
      expect(GroupRules.isValidName('x' * 50), isTrue);
      expect(GroupRules.isValidName('x' * 51), isFalse);
    });

    test('a leaving non-admin keeps the admins unchanged', () {
      final plan = GroupRules.planLeave(
        members: ['a', 'b', 'c'],
        admins: ['a'],
        me: 'c',
      );
      expect(plan.memberIds, ['a', 'b']);
      expect(plan.adminIds, ['a']);
    });

    test('the last admin leaving promotes the first remaining member', () {
      final plan = GroupRules.planLeave(
        members: ['a', 'b', 'c'],
        admins: ['a'],
        me: 'a',
      );
      expect(plan.memberIds, ['b', 'c']);
      expect(plan.adminIds, ['b']);
    });

    test('one of several admins leaving needs no promotion', () {
      final plan = GroupRules.planLeave(
        members: ['a', 'b', 'c'],
        admins: ['a', 'b'],
        me: 'a',
      );
      expect(plan.adminIds, ['b']);
    });

    test('the only member leaving leaves an empty group', () {
      final plan = GroupRules.planLeave(members: ['a'], admins: ['a'], me: 'a');
      expect(plan.memberIds, isEmpty);
      expect(plan.adminIds, isEmpty);
    });

    test('last admin protection', () {
      expect(GroupRules.isLastAdmin(['a'], 'a'), isTrue);
      expect(GroupRules.isLastAdmin(['a', 'b'], 'a'), isFalse);
      expect(GroupRules.isLastAdmin(['a'], 'b'), isFalse);
    });

    test('invite codes match the rules pattern and avoid look-alikes', () {
      final r = Random(1);
      final codes = {
        for (var i = 0; i < 200; i++) GroupRules.generateInviteCode(r),
      };
      expect(codes.length, 200, reason: 'effectively unique');
      for (final c in codes) {
        expect(RegExp(r'^[A-Za-z0-9]{10,24}$').hasMatch(c), isTrue);
        expect(c.contains(RegExp('[0OIl1]')), isFalse);
      }
    });

    test('codes are extracted from pasted share text', () {
      expect(GroupRules.normalizeInviteCode('  abcDEF2345xy '), 'abcDEF2345xy');
      expect(GroupRules.normalizeInviteCode('short'), isNull);
      expect(
        GroupRules.extractInviteCode(
          'Join "Friends" on Hushlo. Use this invite code: kP4tQ9wXz2Ab',
        ),
        'kP4tQ9wXz2Ab',
      );
      expect(GroupRules.extractInviteCode('no code here'), isNull);
    });
  });

  group('Conversation (group)', () {
    const g = Conversation(
      id: 'g_x',
      memberIds: ['me', 'a', 'b', 'c'],
      type: ConversationType.group,
      name: 'Team',
      adminIds: ['me'],
      deletedAccounts: ['c'],
    );
    test('isGroup / admin / membership helpers', () {
      expect(g.isGroup, isTrue);
      expect(g.isAdmin('me'), isTrue);
      expect(g.isAdmin('a'), isFalse);
      expect(g.isMember('b'), isTrue);
      expect(g.isMember('zzz'), isFalse);
    });
    test('othersOf excludes me and deleted accounts', () {
      expect(g.othersOf('me'), ['a', 'b']);
    });
    test('a group is never "other deleted"', () {
      expect(g.otherDeleted('me'), isFalse);
    });
  });

  group('resolveGroupStatus (per-person ticks, aggregated)', () {
    final t0 = DateTime(2026, 1, 1, 10);
    ChatMessage mine() => ChatMessage(
      id: 'm',
      senderId: 'me',
      type: MessageType.text,
      createdAt: t0,
      status: SendStatus.sent,
      text: 'hi',
    );
    Receipts delivered() =>
        Receipts(lastDeliveredAt: t0.add(const Duration(seconds: 1)));
    Receipts read() => Receipts(
      lastDeliveredAt: t0.add(const Duration(seconds: 1)),
      lastReadAt: t0.add(const Duration(seconds: 2)),
    );

    test('sent while anyone has not received it', () {
      expect(
        resolveGroupStatus(mine(), {'a': delivered()}, ['a', 'b']),
        SendStatus.sent,
      );
    });
    test('delivered only when everyone received it', () {
      expect(
        resolveGroupStatus(
          mine(),
          {'a': delivered(), 'b': delivered()},
          ['a', 'b'],
        ),
        SendStatus.delivered,
      );
    });
    test('still delivered while one person has not read it', () {
      expect(
        resolveGroupStatus(mine(), {'a': read(), 'b': delivered()}, ['a', 'b']),
        SendStatus.delivered,
      );
    });
    test('read only when everyone read it', () {
      expect(
        resolveGroupStatus(mine(), {'a': read(), 'b': read()}, ['a', 'b']),
        SendStatus.read,
      );
    });
    test('nobody else in the group -> sent; pending/failed pass through', () {
      expect(resolveGroupStatus(mine(), {}, const []), SendStatus.sent);
      final pending = ChatMessage(
        id: 'p',
        senderId: 'me',
        type: MessageType.text,
        createdAt: t0,
        status: SendStatus.sending,
      );
      expect(
        resolveGroupStatus(pending, {'a': read()}, ['a']),
        SendStatus.sending,
      );
    });
    test('memberStatus gives the individual state for message info', () {
      expect(memberStatus(mine(), read()), SendStatus.read);
      expect(memberStatus(mine(), delivered()), SendStatus.delivered);
      expect(memberStatus(mine(), null), SendStatus.sent);
    });
  });

  group('typingUids', () {
    final now = DateTime(2026, 1, 1, 12);
    test('only recent signals, never me, stable order', () {
      final signals = {
        'zed': now.subtract(const Duration(seconds: 2)),
        'amy': now.subtract(const Duration(seconds: 1)),
        'me': now,
        'old': now.subtract(const Duration(seconds: 30)),
      };
      expect(typingUids(signals, 'me', now), ['amy', 'zed']);
      expect(typingUids(null, 'me', now), isEmpty);
    });
  });

  group('GroupBuilderViewModel', () {
    late FakeGroupRepository groups;
    late FakeProfileRepository profiles;
    late ProviderContainer c;

    GroupBuilderViewModel vm([int cap = 19]) =>
        c.read(groupBuilderProvider(cap).notifier);
    GroupBuilderState st([int cap = 19]) => c.read(groupBuilderProvider(cap));

    setUp(() {
      groups = FakeGroupRepository();
      profiles = FakeProfileRepository();
      c = ProviderContainer(
        overrides: [
          currentUidProvider.overrideWithValue('me'),
          groupRepositoryProvider.overrideWithValue(groups),
          profileRepositoryProvider.overrideWithValue(profiles),
        ],
      );
      c.listen(groupBuilderProvider(19), (_, __) {});
      c.listen(groupBuilderProvider(2), (_, __) {});
    });
    tearDown(() => c.dispose());

    test('toggle selects and deselects in order', () {
      vm().toggle('a');
      vm().toggle('b');
      expect(st().selected, ['a', 'b']);
      vm().toggle('a');
      expect(st().selected, ['b']);
    });

    test('capacity is enforced with a notice', () {
      vm(2).toggle('a');
      vm(2).toggle('b');
      vm(2).toggle('c');
      expect(st(2).selected, ['a', 'b']);
      expect(st(2).notice, 'full');
    });

    test('add by exact username adds the found profile', () async {
      profiles.byUsername['meera_p'] = const Profile(
        uid: 'meera',
        username: 'meera_p',
        displayName: 'Meera',
      );
      await vm().addByUsername('@Meera_P');
      expect(st().selected, ['meera']);
      expect(st().found['meera']?.displayName, 'Meera');
    });

    test('unknown, self and duplicate usernames show notices', () async {
      await vm().addByUsername('nobody_here');
      expect(st().notice, 'notFound');
      profiles.byUsername['me_user'] = const Profile(
        uid: 'me',
        username: 'me_user',
        displayName: 'Me',
      );
      await vm().addByUsername('me_user');
      expect(st().notice, 'self');
      profiles.byUsername['dup_user'] = const Profile(
        uid: 'dup',
        username: 'dup_user',
        displayName: 'Dup',
      );
      await vm().addByUsername('dup_user');
      await vm().addByUsername('dup_user');
      expect(st().notice, 'already');
      expect(st().selected, ['dup']);
    });

    test('create sends the selected members and returns the id', () async {
      vm().toggle('a');
      vm().toggle('b');
      final id = await vm().create('  Weekend plans ');
      expect(id, startsWith('g_'));
      expect(groups.created.single['members'], ['a', 'b']);
      expect(groups.created.single['name'], '  Weekend plans ');
      expect(st().busy, isFalse);
    });

    test('create refuses a blank name or no members', () async {
      expect(await vm().create('Team'), isNull, reason: 'no members');
      vm().toggle('a');
      expect(await vm().create('   '), isNull, reason: 'blank name');
      expect(groups.created, isEmpty);
    });

    test('repository failures surface and clear busy', () async {
      groups.error = StateError('boom');
      vm().toggle('a');
      expect(await vm().create('Team'), isNull);
      expect(st().failure, isNotNull);
      expect(st().busy, isFalse);
    });

    test('addTo adds the selection to an existing group', () async {
      vm().toggle('x');
      expect(await vm().addTo('g_1'), isTrue);
      expect(groups.added.single['uids'], ['x']);
    });
  });
}
