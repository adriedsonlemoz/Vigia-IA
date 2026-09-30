import 'dart:math' as math;

import '../models/rgb_frame.dart';

enum CameraIntegrityIssue { obstructed, moved }

class CameraIntegrityResult {
  const CameraIntegrityResult({
    this.issue,
    required this.brightness,
    required this.sceneDifference,
  });

  final CameraIntegrityIssue? issue;
  final double brightness;
  final double sceneDifference;
}

class CameraIntegrityService {
  CameraIntegrityService({
    this.darkThreshold = 0.055,
    this.sceneChangeThreshold = 0.42,
    this.requiredDarkFrames = 4,
    this.cooldown = const Duration(minutes: 3),
  });

  final double darkThreshold;
  final double sceneChangeThreshold;
  final int requiredDarkFrames;
  final Duration cooldown;

  List<double>? _baseline;
  int _baselineSamples = 0;
  int _darkFrames = 0;
  DateTime? _lastAlert;

  CameraIntegrityResult evaluate(RgbFrame frame, DateTime now) {
    final grid = _grid(frame);
    final brightness = grid.isEmpty ? 0.0 : grid.reduce((a, b) => a + b) / grid.length;
    final previous = _baseline;
    final difference = previous == null ? 0.0 : _meanDifference(previous, grid);

    CameraIntegrityIssue? issue;
    if (brightness < darkThreshold) {
      _darkFrames++;
      if (_darkFrames >= requiredDarkFrames && _cooldownExpired(now)) {
        issue = CameraIntegrityIssue.obstructed;
      }
    } else {
      _darkFrames = 0;
      if (previous != null && _baselineSamples >= 5 && difference >= sceneChangeThreshold && _cooldownExpired(now)) {
        issue = CameraIntegrityIssue.moved;
      }
    }

    if (issue != null) _lastAlert = now;
    if (brightness >= darkThreshold && difference < 0.22) {
      _baseline = _blend(previous, grid);
      _baselineSamples = math.min(_baselineSamples + 1, 50);
    } else if (previous == null) {
      _baseline = grid;
      _baselineSamples = 1;
    }

    return CameraIntegrityResult(issue: issue, brightness: brightness, sceneDifference: difference);
  }

  bool _cooldownExpired(DateTime now) => _lastAlert == null || now.difference(_lastAlert!) >= cooldown;

  List<double> _grid(RgbFrame frame) {
    const cols = 16;
    const rows = 10;
    final result = <double>[];
    final bytes = frame.rgbBytes;
    for (var gy = 0; gy < rows; gy++) {
      final y = ((gy + 0.5) * frame.height / rows).floor().clamp(0, frame.height - 1).toInt();
      for (var gx = 0; gx < cols; gx++) {
        final x = ((gx + 0.5) * frame.width / cols).floor().clamp(0, frame.width - 1).toInt();
        final index = (y * frame.width + x) * 3;
        if (index + 2 >= bytes.length) {
          result.add(0);
          continue;
        }
        final r = bytes[index].toDouble();
        final g = bytes[index + 1].toDouble();
        final b = bytes[index + 2].toDouble();
        result.add((0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0);
      }
    }
    return result;
  }

  double _meanDifference(List<double> a, List<double> b) {
    final count = math.min(a.length, b.length);
    if (count == 0) return 0;
    var total = 0.0;
    for (var i = 0; i < count; i++) {
      total += (a[i] - b[i]).abs();
    }
    return total / count;
  }

  List<double> _blend(List<double>? previous, List<double> current) {
    if (previous == null || previous.length != current.length) return List<double>.from(current);
    return List<double>.generate(current.length, (i) => previous[i] * 0.92 + current[i] * 0.08);
  }

  void reset() {
    _baseline = null;
    _baselineSamples = 0;
    _darkFrames = 0;
    _lastAlert = null;
  }
}
