import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/theme/hushlo_colors.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/hushlo_back_button.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/viewmodels/auth_providers.dart';
import '../../domain/saved_note.dart';
import '../viewmodels/saved_providers.dart';

/// Private notes to yourself, newest at the bottom like a chat.
class SavedMessagesScreen extends ConsumerStatefulWidget {
  const SavedMessagesScreen({super.key});

  @override
  ConsumerState<SavedMessagesScreen> createState() =>
      _SavedMessagesScreenState();
}

class _SavedMessagesScreenState extends ConsumerState<SavedMessagesScreen> {
  final _controller = TextEditingController();
  bool _canSave = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final can = cleanNoteText(_controller.text) != null;
      if (can != _canSave) setState(() => _canSave = can);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _add() async {
    final uid = ref.read(currentUidProvider);
    final text = cleanNoteText(_controller.text);
    if (uid == null || text == null) return;
    _controller.clear();
    try {
      await ref.read(savedRepositoryProvider).add(uid, text);
    } catch (_) {
      if (!mounted) return;
      _controller.text = text; // keep what the user wrote
      _toast(context.l10n.savedFailed);
    }
  }

  Future<void> _actions(SavedNote n) async {
    final l = context.l10n;
    final uid = ref.read(currentUidProvider);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: Text(l.noteCopy),
                  onTap: () => Navigator.pop(ctx, 'copy'),
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: ctx.colors.error,
                  ),
                  title: Text(
                    l.noteDelete,
                    style: TextStyle(color: ctx.colors.error),
                  ),
                  onTap: () => Navigator.pop(ctx, 'delete'),
                ),
              ],
            ),
          ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: n.text));
      if (mounted) _toast(l.noteCopied);
    } else if (uid != null) {
      try {
        await ref.read(savedRepositoryProvider).delete(uid, n.id);
        if (mounted) _toast(l.noteDeleted);
      } catch (e) {
        if (mounted) _toast(failureMessage(l, Failure.from(e)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final notes = ref.watch(savedNotesProvider);
    final locale = Localizations.localeOf(context).toString();

    Widget body = notes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(savedNotesProvider),
          ),
      data: (list) {
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.bookmark_border_rounded,
            title: l.savedEmptyTitle,
            message: l.savedEmptyBody,
          );
        }
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: list.length,
          itemBuilder: (ctx, i) {
            final n = list[i]; // newest first == bottom first
            final older = i + 1 < list.length ? list[i + 1] : null;
            final showDay =
                older == null ||
                !DateFormatter.isSameDay(older.createdAt, n.createdAt);
            return Column(
              children: [
                if (showDay)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      DateFormatter.daySeparator(
                        n.createdAt,
                        locale,
                        today: l.today,
                        yesterday: l.yesterday,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                _NoteCard(
                  note: n,
                  time: DateFormatter.time(n.createdAt, locale),
                  onLongPress: () => _actions(n),
                ),
              ],
            );
          },
        );
      },
    );

    return Scaffold(
      backgroundColor: c.chatBackground,
      appBar: AppBar(
        leading: const HushloBackButton(),
        leadingWidth: 60,
        backgroundColor: c.surface,
        title: Text(l.savedMessages),
      ),
      body: Column(
        children: [
          Expanded(child: body),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: maxSavedNoteLength,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                        decoration: InputDecoration(
                          hintText: l.savedHint,
                          counterText: '',
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: l.savedAdd,
                    onPressed: _canSave ? _add : null,
                    icon: const Icon(Icons.bookmark_add_rounded),
                    constraints: const BoxConstraints(
                      minWidth: 52,
                      minHeight: 52,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.time,
    required this.onLongPress,
  });

  final SavedNote note;
  final String time;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 3, 12, 3),
      child: Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.86,
            ),
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.outline.withValues(alpha: 0.7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (note.sourceName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bookmark_rounded, size: 14, color: c.accent),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            l.savedFrom(note.sourceName!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: c.accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  note.text,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.36),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    note.pending ? '…' : time,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
