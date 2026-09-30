import 'dart:math' as math;

import '../models/detection.dart';
import '../models/object_appearance.dart';
import '../models/object_filter_catalog.dart';
import '../models/rgb_frame.dart';

/// Extrai uma assinatura visual leve do recorte detectado. O detector continua
/// sendo a fonte da classe; cor/aparência entra apenas como pista para manter a
/// identidade da mesma pessoa, animal ou automóvel entre frames e oclusões.
class ObjectAppearanceService {
  const ObjectAppearanceService._();

  static const List<String> _palette = <String>[
    'preto',
    'branco',
    'cinza',
    'vermelho',
    'laranja',
    'amarelo',
    'verde',
    'ciano',
    'azul',
    'roxo',
    'rosa',
    'marrom',
  ];

  static Detection enrich(RgbFrame frame, Detection detection) {
    final appearance = describe(frame, detection);
    if (appearance == null) return detection;
    return detection.copyWith(appearance: appearance);
  }

  static List<Detection> enrichAll(
    RgbFrame frame,
    Iterable<Detection> detections,
  ) =>
      List<Detection>.unmodifiable(
        detections.map((item) => enrich(frame, item)),
      );

  static ObjectAppearance? describe(RgbFrame frame, Detection detection) {
    if (frame.width <= 1 ||
        frame.height <= 1 ||
        frame.rgbBytes.length < frame.width * frame.height * 3) {
      return null;
    }

    final group = ObjectFilterCatalog.groupKeyForLabel(detection.label);
    final box = detection.box;
    final mainRegion = switch (group) {
      'person' => _RelativeRegion(
          xMin: 0.12,
          yMin: 0.10,
          xMax: 0.88,
          yMax: 0.94,
        ),
      'vehicle' => _RelativeRegion(
          xMin: 0.08,
          yMin: 0.28,
          xMax: 0.92,
          yMax: 0.88,
        ),
      _ => _RelativeRegion(
          xMin: 0.10,
          yMin: 0.10,
          xMax: 0.90,
          yMax: 0.90,
        ),
    };

    final main = _sample(frame, box, mainRegion);
    if (main.count < 12) return null;

    String? upper;
    String? lower;
    if (group == 'person') {
      final upperSample = _sample(
        frame,
        box,
        const _RelativeRegion(
          xMin: 0.18,
          yMin: 0.18,
          xMax: 0.82,
          yMax: 0.54,
        ),
      );
      final lowerSample = _sample(
        frame,
        box,
        const _RelativeRegion(
          xMin: 0.20,
          yMin: 0.56,
          xMax: 0.80,
          yMax: 0.94,
        ),
      );
      upper = upperSample.count >= 6 ? _dominant(upperSample.histogram).$1 : null;
      lower = lowerSample.count >= 6 ? _dominant(lowerSample.histogram).$1 : null;
    }

    final dominant = _dominant(main.histogram);
    return ObjectAppearance(
      histogram: List<double>.unmodifiable(main.histogram),
      dominantColor: dominant.$1,
      secondaryColor: dominant.$2,
      upperColor: upper,
      lowerColor: lower,
      sampleCount: main.count,
    );
  }

  /// 0 = aparências muito diferentes; 1 = muito parecidas. A comparação não
  /// exige que a cor dominante seja idêntica, pois luz/sombra alteram cores.
  static double similarity(ObjectAppearance? a, ObjectAppearance? b) {
    if (a == null || b == null) return 0.5;
    final length = math.min(a.histogram.length, b.histogram.length);
    if (length == 0) return 0.5;

    var histogramIntersection = 0.0;
    for (var i = 0; i < length; i++) {
      histogramIntersection += math.min(a.histogram[i], b.histogram[i]);
    }
    histogramIntersection = histogramIntersection.clamp(0.0, 1.0).toDouble();

    var weighted = histogramIntersection * 0.70;
    var weight = 0.70;
    weighted += (a.dominantColor == b.dominantColor ? 1.0 : 0.0) * 0.12;
    weight += 0.12;

    if (a.upperColor != null && b.upperColor != null) {
      weighted += (a.upperColor == b.upperColor ? 1.0 : 0.0) * 0.09;
      weight += 0.09;
    }
    if (a.lowerColor != null && b.lowerColor != null) {
      weighted += (a.lowerColor == b.lowerColor ? 1.0 : 0.0) * 0.09;
      weight += 0.09;
    }
    return (weighted / weight).clamp(0.0, 1.0).toDouble();
  }

  static _ColorSample _sample(
    RgbFrame frame,
    NormalizedBox box,
    _RelativeRegion region,
  ) {
    final left = box.xMin.clamp(0.0, 1.0).toDouble();
    final top = box.yMin.clamp(0.0, 1.0).toDouble();
    final right = box.xMax.clamp(0.0, 1.0).toDouble();
    final bottom = box.yMax.clamp(0.0, 1.0).toDouble();
    final width = math.max(0.0, right - left);
    final height = math.max(0.0, bottom - top);
    if (width <= 0 || height <= 0) {
      return _ColorSample(List<double>.filled(_palette.length, 0), 0);
    }

    final startX = ((left + width * region.xMin) * frame.width)
        .floor()
        .clamp(0, frame.width - 1)
        .toInt();
    final endX = ((left + width * region.xMax) * frame.width)
        .ceil()
        .clamp(startX + 1, frame.width)
        .toInt();
    final startY = ((top + height * region.yMin) * frame.height)
        .floor()
        .clamp(0, frame.height - 1)
        .toInt();
    final endY = ((top + height * region.yMax) * frame.height)
        .ceil()
        .clamp(startY + 1, frame.height)
        .toInt();

    final spanX = endX - startX;
    final spanY = endY - startY;
    final targetSamples =
        math.min(900, math.max(80, spanX * spanY)).toInt();
    final step = math.max(
      1,
      math.sqrt((spanX * spanY) / targetSamples).floor(),
    ).toInt();
    final counts = List<double>.filled(_palette.length, 0);
    var total = 0;

    for (var y = startY; y < endY; y += step) {
      for (var x = startX; x < endX; x += step) {
        final offset = (y * frame.width + x) * 3;
        if (offset + 2 >= frame.rgbBytes.length) continue;
        final r = frame.rgbBytes[offset];
        final g = frame.rgbBytes[offset + 1];
        final b = frame.rgbBytes[offset + 2];
        final colorIndex = _classify(r, g, b);
        counts[colorIndex] += 1;
        total++;
      }
    }
    if (total > 0) {
      for (var i = 0; i < counts.length; i++) {
        counts[i] /= total;
      }
    }
    return _ColorSample(counts, total);
  }

  static int _classify(int r, int g, int b) {
    final rd = r / 255.0;
    final gd = g / 255.0;
    final bd = b / 255.0;
    final maxChannel = math.max(rd, math.max(gd, bd));
    final minChannel = math.min(rd, math.min(gd, bd));
    final delta = maxChannel - minChannel;
    final value = maxChannel;
    final saturation = maxChannel <= 0 ? 0.0 : delta / maxChannel;

    if (value < 0.20) return 0; // preto
    if (saturation < 0.12 && value > 0.82) return 1; // branco
    if (saturation < 0.16) return 2; // cinza

    var hue = 0.0;
    if (delta > 0) {
      if (maxChannel == rd) {
        hue = 60 * (((gd - bd) / delta) % 6);
      } else if (maxChannel == gd) {
        hue = 60 * (((bd - rd) / delta) + 2);
      } else {
        hue = 60 * (((rd - gd) / delta) + 4);
      }
    }
    if (hue < 0) hue += 360;

    // Tons escuros alaranjados/amarelados são normalmente marrom na câmera.
    if (value < 0.58 && hue >= 12 && hue < 55) return 11;
    if (hue < 12 || hue >= 345) return 3;
    if (hue < 38) return 4;
    if (hue < 66) return 5;
    if (hue < 165) return 6;
    if (hue < 195) return 7;
    if (hue < 252) return 8;
    if (hue < 292) return 9;
    if (hue < 345) return 10;
    return 3;
  }

  static (String, String?) _dominant(List<double> histogram) {
    if (histogram.isEmpty) return ('indefinida', null);
    final indexes = List<int>.generate(histogram.length, (index) => index)
      ..sort((a, b) => histogram[b].compareTo(histogram[a]));
    final first = indexes.first;
    final second = indexes.length > 1 ? indexes[1] : first;
    final secondary = histogram[second] >= 0.18 ? _palette[second] : null;
    return (_palette[first], secondary);
  }
}

class _RelativeRegion {
  const _RelativeRegion({
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
  });

  final double xMin;
  final double yMin;
  final double xMax;
  final double yMax;
}

class _ColorSample {
  const _ColorSample(this.histogram, this.count);
  final List<double> histogram;
  final int count;
}
