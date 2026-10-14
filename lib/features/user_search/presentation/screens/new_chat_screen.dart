import '../../../../core/widgets/hushlo_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/theme/hushlo_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../profile/presentation/viewmodels/profile_providers.dart';
import '../viewmodels/user_search_view_model.dart';

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    FocusScope.of(context).unfocus();
    ref.read(userSearchViewModelProvider.notifier).search(_controller.text);
  }

  Future<void> _message() async {
    final id = await ref.read(userSearchViewModelProvider.notifier).message();
    if (id != null && mounted) context.pushReplacement('/chat/$id');
  }

  Future<void> _invite() async {
    final l = context.l10n;
    final me = ref.read(currentProfileProvider).value;
    final link =
        AppConfig.webBaseUrl.isEmpty ? '' : '\n${AppConfig.webBaseUrl}';
    await SharePlus.instance.share(
      ShareParams(text: l.inviteText(me?.username ?? '') + link),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final s = ref.watch(userSearchViewModelProvider);

    Widget result;
    switch (s.phase) {
      case SearchPhase.idle:
        result = Column(
          children: [
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: Image.asset(
                'assets/illustrations/empty_chats.png',
                height: 190,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.searchHint,
              textAlign: TextAlign.center,
              style: t.bodyMedium?.copyWith(color: c.textSecondary),
            ),
          ],
        );
      case SearchPhase.searching:
        result = const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        );
      case SearchPhase.notFound:
        result = _Notice(icon: Icons.search_off_rounded, text: l.userNotFound);
      case SearchPhase.isSelf:
        result = _Notice(
          icon: Icons.person_off_outlined,
          text: l.errSelfConversation,
        );
      case SearchPhase.error:
        result = _Notice(
          icon: Icons.error_outline_rounded,
          text: s.failure == null ? '' : failureMessage(l, s.failure!),
          color: c.error,
        );
      case SearchPhase.found:
        final p = s.result!;
        result = Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: c.outline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      c.bubbleOut,
                      c.bubbleOutEnd,
                      c.accent.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -38),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: c.surface,
                        shape: BoxShape.circle,
                      ),
                      child: UserAvatar(
                        name: p.displayName,
                        photoPath: p.photoPath,
                        size: 76,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(p.displayName, style: t.titleLarge),
                    Text(
                      '@${p.username}',
                      style: t.bodyMedium?.copyWith(color: c.textSecondary),
                    ),
                    if ((p.bio ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                        child: Text(
                          p.bio!,
                          textAlign: TextAlign.center,
                          style: t.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Transform.translate(
                  offset: const Offset(0, -22),
                  child: FilledButton.icon(
                    onPressed: s.starting ? null : _message,
                    icon:
                        s.starting
                            ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: c.onPrimary,
                              ),
                            )
                            : const Icon(Icons.chat_bubble_rounded, size: 20),
                    label: Text(l.message),
                  ),
                ),
              ),
            ],
          ),
        );
    }

    return Scaffold(
      appBar: AppBar(
        leading: const HushloBackButton(),
        leadingWidth: 60,
        title: Text(l.newChat),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_@]')),
              ],
              decoration: InputDecoration(
                hintText: l.exactUsername,
                prefixIcon: const Icon(Icons.alternate_email_rounded),
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(6),
                  child: IconButton.filled(
                    tooltip: l.search,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    onPressed: _search,
                    style: IconButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: c.onPrimary,
                    ),
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: c.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: c.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: c.primary, width: 1.8),
                ),
              ),
            ),
            const SizedBox(height: 20),
            result,
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              decoration: BoxDecoration(
                color: c.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c.primary.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_add_alt_1_rounded,
                      color: c.primary,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.inviteFriend,
                      style: t.titleSmall?.copyWith(fontSize: 15),
                    ),
                  ),
                  FilledButton(
                    onPressed: _invite,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(80, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      textStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Icon(Icons.ios_share_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final col = color ?? c.textSecondary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.outline),
      ),
      child: Row(
        children: [
          Icon(icon, color: col),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: col),
            ),
          ),
        ],
      ),
    );
  }
}
