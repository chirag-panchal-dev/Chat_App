import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/theme/hushlo_colors.dart';
import '../../../../core/widgets/hushlo_back_button.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/viewmodels/auth_providers.dart';
import '../../../conversations/presentation/viewmodels/conversation_providers.dart';
import '../../domain/group_models.dart';
import '../../domain/group_rules.dart';
import '../viewmodels/group_providers.dart';

/// Enter an invite code, preview the group and ask to join. An admin has to
/// approve the request.
class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  final _code = TextEditingController();
  GroupInvite? _invite;
  bool _busy = false;
  bool _notFound = false;
  Failure? _failure;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final code = GroupRules.extractInviteCode(data?.text ?? '');
    if (code != null) setState(() => _code.text = code);
  }

  Future<void> _find() async {
    FocusScope.of(context).unfocus();
    final code = GroupRules.extractInviteCode(_code.text);
    if (code == null) {
      setState(() {
        _notFound = true;
        _invite = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _notFound = false;
      _failure = null;
    });
    try {
      final inv = await ref.read(groupRepositoryProvider).lookupInvite(code);
      if (!mounted) return;
      setState(() {
        _invite = inv;
        _notFound = inv == null;
        _busy = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _failure = Failure.from(e);
          _busy = false;
        });
      }
    }
  }

  Future<void> _request(GroupInvite inv) async {
    final me = ref.read(currentUidProvider);
    if (me == null) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref
          .read(groupRepositoryProvider)
          .requestJoin(code: inv.code, me: me);
    } catch (e) {
      if (mounted) _failure = Failure.from(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final me = ref.watch(currentUidProvider);
    final inv = _invite;

    final inbox = ref.watch(inboxProvider).value;
    final alreadyMember =
        inv != null &&
        inbox != null &&
        [
          ...inbox.active,
          ...inbox.archived,
        ].any((x) => x.conversation.id == inv.groupId);
    final pending =
        inv != null && !alreadyMember
            ? ref.watch(myJoinRequestProvider(inv.groupId)).value ?? false
            : false;

    return Scaffold(
      appBar: AppBar(
        leading: const HushloBackButton(),
        leadingWidth: 60,
        title: Text(l.joinGroupTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text(l.joinGroupHelp, style: t.bodyMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _find(),
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
              decoration: InputDecoration(
                labelText: l.enterInviteCode,
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                suffixIcon: TextButton(
                  onPressed: _paste,
                  child: Text(l.pasteCode),
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _busy ? null : _find,
              child:
                  _busy && inv == null
                      ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: c.onPrimary,
                        ),
                      )
                      : Text(l.findGroup),
            ),
            if (_notFound)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    l.invalidInviteCode,
                    style: t.bodyMedium?.copyWith(color: c.error),
                  ),
                ),
              ),
            if (_failure != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  failureMessage(l, _failure!),
                  style: t.bodyMedium?.copyWith(color: c.error),
                ),
              ),
            if (inv != null && me != null) ...[
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      UserAvatar(name: inv.groupName, size: 72, group: true),
                      const SizedBox(height: 12),
                      Text(
                        inv.groupName,
                        textAlign: TextAlign.center,
                        style: t.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      if (alreadyMember) ...[
                        Text(l.alreadyMember, style: t.bodyMedium),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed:
                              () => context.pushReplacement(
                                '/chat/${inv.groupId}',
                              ),
                          child: Text(l.message),
                        ),
                      ] else if (pending) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.hourglass_top_rounded,
                              size: 18,
                              color: c.success,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                l.requestSent,
                                style: t.bodyMedium?.copyWith(color: c.success),
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed:
                              () => ref
                                  .read(groupRepositoryProvider)
                                  .cancelJoinRequest(
                                    groupId: inv.groupId,
                                    me: me,
                                  ),
                          child: Text(l.cancelRequest),
                        ),
                      ] else
                        FilledButton.icon(
                          onPressed: _busy ? null : () => _request(inv),
                          icon: const Icon(Icons.login_rounded, size: 20),
                          label: Text(l.requestToJoin),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
