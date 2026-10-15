import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_ext.dart';
import '../../../core/widgets/hushlo_mark.dart';
import '../domain/app_lock_models.dart';
import 'app_lock_controller.dart';

/// Wraps the whole app: shows the lock screen while locked and a privacy cover
/// while the app is inactive (so the app switcher never shows chats).
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  @override
  void initState() {
    super.initState();
    // Cold start while locked: prompt right away.
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptIfLocked());
  }

  void _promptIfLocked() {
    if (!mounted) return;
    if (ref.read(appLockProvider).locked) {
      ref.read(appLockProvider.notifier).unlock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(appLockProvider);
    ref.read(appLockProvider.notifier).unlockReason = l.unlockReason;

    // Returning to the app after the timeout: prompt automatically.
    ref.listen<bool>(appLockProvider.select((x) => x.locked), (prev, next) {
      if (next && prev != true) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _promptIfLocked());
      }
    });

    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        // Content stays mounted (state preserved) but is inert while locked.
        Positioned.fill(
          child: IgnorePointer(
            ignoring: s.locked,
            child: ExcludeSemantics(excluding: s.locked, child: widget.child),
          ),
        ),
        if (s.locked)
          Positioned.fill(
            child: _LockScreen(
              busy: s.authenticating,
              outcome: s.lastOutcome,
              onUnlock: () => ref.read(appLockProvider.notifier).unlock(),
            ),
          )
        else if (s.obscured)
          const Positioned.fill(child: _PrivacyCover()),
      ],
    );
  }
}

const _ink = Color(0xFF0C131A);

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(-0.6, -0.9),
        radius: 1.4,
        colors: [Color(0xFF16424A), _ink],
      ),
    ),
    child: child,
  );
}

/// Opaque cover shown in the app switcher.
class _PrivacyCover extends StatelessWidget {
  const _PrivacyCover();

  @override
  Widget build(BuildContext context) =>
      const _Backdrop(child: Center(child: HushloMark(size: 96)));
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({
    required this.busy,
    required this.outcome,
    required this.onUnlock,
  });

  final bool busy;
  final AuthOutcome? outcome;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final message = switch (outcome) {
      AuthOutcome.lockedOut => l.lockedOutMessage,
      AuthOutcome.failed => l.lockVerifyFailed,
      AuthOutcome.notAvailable => l.lockNotAvailable,
      _ => null,
    };
    return Material(
      color: _ink,
      child: _Backdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const HushloMark(size: 88),
                    const SizedBox(height: 28),
                    Semantics(
                      header: true,
                      child: Text(
                        l.lockedTitle,
                        textAlign: TextAlign.center,
                        style: t.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.lockedBody,
                      textAlign: TextAlign.center,
                      style: t.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: t.bodyMedium?.copyWith(
                            color: const Color(0xFFFFB4A8),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: busy ? null : onUnlock,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF43CDB8),
                        foregroundColor: _ink,
                        minimumSize: const Size(220, 56),
                      ),
                      icon: const Icon(Icons.lock_open_rounded),
                      label: Text(l.unlockButton),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
