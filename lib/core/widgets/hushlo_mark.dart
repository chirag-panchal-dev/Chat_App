import 'package:flutter/material.dart';

/// The Hushlo brand mark (original artwork, see assets/branding).
class HushloMark extends StatelessWidget {
  const HushloMark({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/hushlo_mark.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );
  }
}
