import 'package:flutter/material.dart';

import '../errors/failure.dart';
import '../l10n/l10n_ext.dart';
import '../theme/hushlo_colors.dart';

/// Friendly empty state with an optional next action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.illustration,
  });

  /// Optional bundled illustration (assets/illustrations/...). Replaces the icon.
  final String? illustration;
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (illustration != null)
              ExcludeSemantics(
                child: Image.asset(
                  illustration!,
                  height: 190,
                  fit: BoxFit.contain,
                ),
              )
            else
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: c.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: c.primary),
              ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 52),
                  shape: const StadiumBorder(),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Recoverable error with a retry action. Permission errors are shown without
/// a retry button because retrying will not help.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final failure = Failure.from(error);
    final canRetry = onRetry != null && failure is! PermissionFailure;
    return EmptyState(
      icon:
          failure is NetworkFailure
              ? Icons.cloud_off_rounded
              : Icons.error_outline_rounded,
      title: l.errorTitle,
      message: failureMessage(l, failure),
      actionLabel: canRetry ? l.retry : null,
      onAction: onRetry,
    );
  }
}

/// Low-contrast skeleton row; static under reduced motion.
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.count = 8});
  final int count;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: context.l10n.loading,
      child: ExcludeSemantics(
        child: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.count,
          itemBuilder:
              (_, __) => AnimatedBuilder(
                animation: _c,
                builder: (_, __) {
                  final color =
                      Color.lerp(c.surfaceSubtle, c.outline, _c.value * 0.6)!;
                  Widget bar(double w, double h) => Container(
                    width: w,
                    height: h,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              bar(140, 14),
                              const SizedBox(height: 10),
                              bar(double.infinity, 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
        ),
      ),
    );
  }
}

/// Subtle, non-blocking banner shown while the device is offline.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: c.surfaceSubtle,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, size: 18, color: c.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.offlineBanner,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
