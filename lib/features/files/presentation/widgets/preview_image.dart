import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/media_url_provider.dart';

/// A small bubble preview (PDF first page / video frame) loaded through the
/// same signed-URL cache as photos. Shows [fallback] while loading and when
/// it can't be loaded, so the bubble never looks broken.
class PreviewImage extends ConsumerWidget {
  const PreviewImage({
    super.key,
    required this.path,
    required this.fallback,
    this.alignment = Alignment.center,
  });

  final String path;
  final Widget fallback;
  final Alignment alignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(mediaUrlProvider(path));
    return url.when(
      data:
          (u) => CachedNetworkImage(
            imageUrl: u,
            cacheKey: path,
            fit: BoxFit.cover,
            alignment: alignment,
            memCacheWidth: 640,
            placeholder: (_, __) => fallback,
            errorWidget: (_, __, ___) => fallback,
          ),
      loading: () => fallback,
      error: (_, __) => fallback,
    );
  }
}
