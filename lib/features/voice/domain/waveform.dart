import 'dart:math';

import 'voice_models.dart';

/// Turns raw amplitude samples (dBFS, roughly -60..0) into [bars] heights in
/// 0..100 by bucketing and taking each bucket's loudest sample, so short
/// peaks survive. Quiet audio still gets a small visible bar.
List<int> normalizeWaveform(
  List<double> dbSamples, {
  int bars = VoiceLimits.waveformBars,
  double floorDb = -60,
}) {
  if (bars <= 0) return const [];
  if (dbSamples.isEmpty) return List<int>.filled(bars, 8);

  int level(double db) {
    final clamped = db.isNaN ? floorDb : db.clamp(floorDb, 0.0);
    final v = (clamped - floorDb) / -floorDb; // 0..1
    // Gentle curve so speech isn't a flat line.
    return max(8, (pow(v, 0.8) * 100).round().clamp(0, 100));
  }

  final out = <int>[];
  final per = dbSamples.length / bars;
  for (var i = 0; i < bars; i++) {
    final start = (i * per).floor();
    var end = ((i + 1) * per).ceil();
    if (end <= start) end = start + 1;
    var peak = floorDb;
    for (var j = start; j < min(end, dbSamples.length); j++) {
      if (dbSamples[j] > peak) peak = dbSamples[j];
    }
    out.add(level(peak));
  }
  return out;
}
