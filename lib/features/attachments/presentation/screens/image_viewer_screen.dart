import '../../../../core/widgets/hushlo_back_button.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/media_url_provider.dart';
import '../../../../core/l10n/l10n_ext.dart';

/// Full-size viewer. The list only loads thumbnails; the full image is
/// fetched here, with the thumbnail shown while it loads.
class ImageViewerScreen extends ConsumerWidget {
  const ImageViewerScreen({super.key, required this.path, this.thumbPath});
  final String path;
  final String? thumbPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(mediaUrlProvider(path));
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: HushloBackButton(
          onDark: true,
          icon: Icons.close_rounded,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Center(
        child: url.when(
          data:
              (u) => InteractiveViewer(
                maxScale: 5,
                child: CachedNetworkImage(
                  imageUrl: u,
                  cacheKey: path,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const CircularProgressIndicator(),
                  errorWidget:
                      (_, __, ___) => _Error(
                        onRetry: () => ref.invalidate(mediaUrlProvider(path)),
                      ),
                ),
              ),
          loading: () => const CircularProgressIndicator(),
          error:
              (_, __) =>
                  _Error(onRetry: () => ref.invalidate(mediaUrlProvider(path))),
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.broken_image_outlined, color: Colors.white70, size: 48),
      const SizedBox(height: 12),
      TextButton(onPressed: onRetry, child: Text(context.l10n.retry)),
    ],
  );
}
