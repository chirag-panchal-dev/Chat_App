import 'package:flutter/material.dart';

/// Bars 0..100 drawn left to right; bars before [progress] use [playedColor].
class WaveformView extends StatelessWidget {
  const WaveformView({
    super.key,
    required this.bars,
    required this.progress,
    required this.playedColor,
    required this.idleColor,
    this.height = 30,
  });

  final List<int> bars;
  final double progress;
  final Color playedColor;
  final Color idleColor;
  final double height;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.fromHeight(height),
    painter: _WavePainter(bars, progress, playedColor, idleColor),
  );
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.bars, this.progress, this.played, this.idle);
  final List<int> bars;
  final double progress;
  final Color played;
  final Color idle;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    const gap = 2.0;
    final w = (size.width - gap * (bars.length - 1)) / bars.length;
    final barW = w.clamp(1.5, 4.0);
    final step = size.width / bars.length;
    final paint =
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = barW;
    for (var i = 0; i < bars.length; i++) {
      final x = step * i + step / 2;
      final h = (bars[i].clamp(6, 100) / 100) * size.height;
      paint.color = (i + 0.5) / bars.length <= progress ? played : idle;
      canvas.drawLine(
        Offset(x, (size.height - h) / 2),
        Offset(x, (size.height + h) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter o) =>
      o.progress != progress ||
      o.played != played ||
      o.idle != idle ||
      o.bars != bars;
}
