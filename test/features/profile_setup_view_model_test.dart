import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hushlo/core/errors/failure.dart';
import 'package:hushlo/features/auth/presentation/viewmodels/auth_providers.dart';
import 'package:hushlo/features/profile/presentation/viewmodels/profile_providers.dart';
import 'package:hushlo/features/profile/presentation/viewmodels/profile_setup_view_model.dart';

import 'fakes.dart';

void main() {
  late FakeProfileRepository repo;
  late ProviderContainer c;

  setUp(() {
    repo = FakeProfileRepository();
    c = ProviderContainer(
      overrides: [
        currentUidProvider.overrideWithValue('u1'),
        profileRepositoryProvider.overrideWithValue(repo),
      ],
    );
    c.listen(profileSetupViewModelProvider, (_, __) {});
  });
  tearDown(() => c.dispose());

  ProfileSetupViewModel vm() => c.read(profileSetupViewModelProvider.notifier);
  ProfileSetupState s() => c.read(profileSetupViewModelProvider);

  test('invalid usernames never hit the network', () async {
    vm().usernameChanged('a');
    expect(s().username, UsernameStatus.invalid);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(repo.availabilityChecks, 0);
  });

  test('debounces rapid typing into a single availability check', () async {
    vm().usernameChanged('sam');
    vm().usernameChanged('sam_');
    vm().usernameChanged('sam_u');
    expect(s().username, UsernameStatus.checking);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(repo.availabilityChecks, 1);
    expect(s().username, UsernameStatus.available);
  });

  test('taken username is reported', () async {
    repo.taken.add('sam_u');
    vm().usernameChanged('Sam_U');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(s().username, UsernameStatus.taken);
  });

  test('submit creates the profile with the normalized username', () async {
    final ok = await vm().submit(username: ' @Sam_U ', displayName: ' Sam ');
    expect(ok, isTrue);
    expect(repo.created?.username, 'sam_u');
    expect(repo.created?.uid, 'u1');
  });

  test('losing the username race shows taken and does not succeed', () async {
    repo.createError = const ValidationFailure(ValidationReason.usernameTaken);
    final ok = await vm().submit(username: 'sam_u', displayName: 'Sam');
    expect(ok, isFalse);
    expect(s().username, UsernameStatus.taken);
    expect(s().busy, isFalse);
  });

  test('blank display name is rejected', () async {
    final ok = await vm().submit(username: 'sam_u', displayName: '  ');
    expect(ok, isFalse);
    expect(s().failure, isA<ValidationFailure>());
    expect(repo.created, isNull);
  });
}
