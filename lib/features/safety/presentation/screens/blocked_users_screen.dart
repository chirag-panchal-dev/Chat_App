import '../../../../core/widgets/hushlo_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/viewmodels/auth_providers.dart';
import '../../../profile/presentation/viewmodels/profile_providers.dart';
import '../viewmodels/safety_providers.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final blocked = ref.watch(blockedUidsProvider);
    final me = ref.watch(currentUidProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const HushloBackButton(),
        leadingWidth: 60,
        title: Text(l.blockedUsers),
      ),
      body: blocked.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => ErrorState(
              error: e,
              onRetry: () => ref.invalidate(blockedUidsProvider),
            ),
        data:
            (uids) =>
                uids.isEmpty
                    ? EmptyState(
                      illustration: 'assets/illustrations/no_blocked.png',
                      icon: Icons.block_outlined,
                      title: l.noBlockedTitle,
                      message: l.noBlockedBody,
                    )
                    : ListView(
                      children: [
                        for (final uid in uids)
                          Consumer(
                            builder: (context, ref, _) {
                              final p =
                                  ref.watch(profileByUidProvider(uid)).value;
                              final name = p?.displayName ?? l.deletedAccount;
                              return ListTile(
                                leading: UserAvatar(
                                  name: name,
                                  photoPath: p?.photoPath,
                                  size: 44,
                                ),
                                title: Text(name),
                                subtitle:
                                    p == null ? null : Text('@${p.username}'),
                                trailing: TextButton(
                                  onPressed:
                                      me == null
                                          ? null
                                          : () => ref
                                              .read(safetyRepositoryProvider)
                                              .unblock(me, uid),
                                  child: Text(l.unblock),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
      ),
    );
  }
}
