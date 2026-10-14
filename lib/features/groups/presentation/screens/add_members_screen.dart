import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/theme/hushlo_colors.dart';
import '../../../../core/widgets/hushlo_back_button.dart';
import '../../../conversations/presentation/viewmodels/conversation_providers.dart';
import '../../domain/group_rules.dart';
import '../viewmodels/group_builder_view_model.dart';
import '../widgets/contact_picker.dart';

/// Admin-only: add people to an existing group (capacity = remaining slots).
class AddMembersScreen extends ConsumerWidget {
  const AddMembersScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.colors;
    final conv = ref.watch(conversationProvider(groupId)).value;
    final members = conv?.memberIds ?? const <String>[];
    final capacity = GroupRules.remainingSlots(members.length);

    return Scaffold(
      appBar: AppBar(
        leading: const HushloBackButton(),
        leadingWidth: 60,
        title: Text(l.addMembers),
      ),
      body: SafeArea(
        child:
            conv == null
                ? const Center(child: CircularProgressIndicator())
                : capacity == 0
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l.groupFull(20),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                )
                : Column(
                  children: [
                    Expanded(
                      child: ContactPicker(
                        capacity: capacity,
                        exclude: members.toSet(),
                      ),
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final s = ref.watch(groupBuilderProvider(capacity));
                        return Container(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                          decoration: BoxDecoration(
                            color: c.background,
                            border: Border(
                              top: BorderSide(
                                color: c.outline.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                          child: SafeArea(
                            top: false,
                            child: FilledButton(
                              onPressed:
                                  s.selected.isEmpty || s.busy
                                      ? null
                                      : () async {
                                        final ok = await ref
                                            .read(
                                              groupBuilderProvider(
                                                capacity,
                                              ).notifier,
                                            )
                                            .addTo(groupId);
                                        if (ok && context.mounted) {
                                          context.pop();
                                        }
                                      },
                              child:
                                  s.busy
                                      ? SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: c.onPrimary,
                                        ),
                                      )
                                      : Text(l.addMembers),
                            ),
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
