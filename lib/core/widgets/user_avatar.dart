import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/media_url_provider.dart';

/// Deterministic, pleasant gradient per name so avatars are easy to tell apart.
List<Color> avatarGradient(String name) {
  const pairs = [
    [Color(0xFF43CDB8), Color(0xFF1E8FA8)],
    [Color(0xFF8C83F6), Color(0xFF5B4FE0)],
    [Color(0xFFFF9A6C), Color(0xFFF0586B)],
    [Color(0xFF5CC8FF), Color(0xFF3B82F6)],
    [Color(0xFFF6B94A), Color(0xFFEF8A3C)],
    [Color(0xFF7BDCB5), Color(0xFF2FB38F)],
    [Color(0xFFF58AC7), Color(0xFFC25BD8)],
    [Color(0xFF9AA7FF), Color(0xFF5B6CFF)],
  ];
  var h = 0;
  for (final u in name.runes) {
    h = (h * 31 + u) & 0x7fffffff;
  }
  return pairs[h % pairs.length];
}

/// Avatar showing the user's photo when available, otherwise initials.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.photoPath,
    this.size = 48,
    this.group = false,
  });

  final String name;
  final String? photoPath;
  final double size;

  /// Group avatar: shows a people icon instead of initials when there's no photo.
  final bool group;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final first = parts.first.characters.first.toUpperCase();
    final last =
        parts.length > 1 ? parts.last.characters.first.toUpperCase() : '';
    return '$first$last';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pair = avatarGradient(name);
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pair,
        ),
      ),
      child:
          group
              ? Icon(
                Icons.groups_rounded,
                color: Colors.white,
                size: size * 0.52,
              )
              : Text(
                _initials,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: size * 0.38,
                  letterSpacing: -0.3,
                ),
              ),
    );
    final path = photoPath;
    if (path == null || path.isEmpty) return ExcludeSemantics(child: fallback);

    final url = ref.watch(mediaUrlProvider(path));
    return ExcludeSemantics(
      child: url.when(
        data:
            (u) => ClipOval(
              child: CachedNetworkImage(
                imageUrl: u,
                cacheKey: path,
                width: size,
                height: size,
                fit: BoxFit.cover,
                memCacheWidth: (size * 3).round(),
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              ),
            ),
        loading: () => fallback,
        error: (_, __) => fallback,
      ),
    );
  }
}
