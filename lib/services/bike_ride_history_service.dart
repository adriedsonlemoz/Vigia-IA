import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/bike_ride_history.dart';
import '../models/map_route_point.dart';
import 'location_tracking_service.dart';

class BikeRideHistoryAnalyzer {
  const BikeRideHistoryAnalyzer();

  static const double minimumDistanceMeters = 3000;
  static const Duration minimumElapsedDuration = Duration(minutes: 12);
  static const Duration minimumMovingDuration = Duration(minutes: 10);
  static const double minimumMovingSpeedKmh = 6;
  static const double maximumMovingSpeedKmh = 35;
  static const double maximumAcceptedSegmentSpeedKmh = 48;
  static const Duration maximumMovingSampleGap = Duration(seconds: 20);

  BikeRideHistoryEntry? analyze({
    required List<List<MapRoutePoint>> segments,
    required double distanceMeters,
    required Duration elapsedDuration,
    required DateTime startedAt,
    required DateTime endedAt,
  }) {
    if (distanceMeters < minimumDistanceMeters ||
        elapsedDuration < minimumElapsedDuration) {
      return null;
    }

    var movingMeters = 0.0;
    var movingSeconds = 0.0;
    var suspiciousMeters = 0.0;
    for (final segment in segments) {
      for (var index = 1; index < segment.length; index++) {
        final previous = segment[index - 1];
        final current = segment[index];
        final delta = current.recordedAt.difference(previous.recordedAt);
        if (delta <= Duration.zero || delta > maximumMovingSampleGap) continue;
        final meters = LocationTrackingService.distanceMeters(previous, current);
        if (!meters.isFinite || meters <= 0 || meters > 250) continue;
        final seconds = delta.inMilliseconds / 1000.0;
        if (seconds <= 0) continue;
        final segmentSpeedKmh = meters / seconds * 3.6;
        if (!segmentSpeedKmh.isFinite) continue;
        if (segmentSpeedKmh > maximumAcceptedSegmentSpeedKmh) {
          suspiciousMeters += meters;
          continue;
        }
        if (segmentSpeedKmh < 2.5) continue;
        movingMeters += meters;
        movingSeconds += seconds;
      }
    }

    final minimumCoveredMeters = math.max(
      minimumDistanceMeters * 0.75,
      distanceMeters * 0.60,
    );
    if (movingSeconds < minimumMovingDuration.inSeconds ||
        movingMeters < minimumCoveredMeters) {
      return null;
    }
    if (suspiciousMeters > math.max(500.0, distanceMeters * 0.08)) {
      return null;
    }

    final movingSpeedKmh = movingMeters / 1000 / (movingSeconds / 3600);
    final elapsedHours = elapsedDuration.inSeconds / 3600;
    final overallSpeedKmh = elapsedHours <= 0
        ? 0.0
        : distanceMeters / 1000 / elapsedHours;
    if (!movingSpeedKmh.isFinite ||
        movingSpeedKmh < minimumMovingSpeedKmh ||
        movingSpeedKmh > maximumMovingSpeedKmh ||
        !overallSpeedKmh.isFinite ||
        overallSpeedKmh < 3 ||
        overallSpeedKmh > maximumMovingSpeedKmh) {
      return null;
    }

    return BikeRideHistoryEntry(
      startedAt: startedAt,
      endedAt: endedAt,
      distanceMeters: distanceMeters,
      movingDuration: Duration(seconds: movingSeconds.round()),
      elapsedDuration: elapsedDuration,
      movingAverageSpeedKmh: movingSpeedKmh,
      overallAverageSpeedKmh: overallSpeedKmh,
    );
  }

  BikeRideHistorySummary summarize(List<BikeRideHistoryEntry> entries) {
    if (entries.isEmpty) return BikeRideHistorySummary.empty;
    final speeds = entries
        .map((entry) => entry.movingAverageSpeedKmh)
        .where((speed) => speed.isFinite)
        .toList(growable: false)
      ..sort();
    final overallSpeeds = entries
        .map((entry) => entry.overallAverageSpeedKmh)
        .where((speed) => speed.isFinite)
        .toList(growable: false)
      ..sort();
    if (speeds.isEmpty || overallSpeeds.isEmpty) {
      return BikeRideHistorySummary.empty;
    }

    final learnedMoving = _robustAverage(speeds);
    final learnedOverall = _robustAverage(overallSpeeds);
    final totalDistance = entries.fold<double>(
      0,
      (sum, entry) => sum + entry.distanceMeters,
    );
    final totalMovingSeconds = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.movingDuration.inSeconds,
    );
    final reliable = entries.length >= 3 &&
        totalDistance >= 20000 &&
        totalMovingSeconds >= const Duration(minutes: 90).inSeconds;
    return BikeRideHistorySummary(
      rideCount: entries.length,
      totalDistanceMeters: totalDistance,
      totalMovingDuration: Duration(seconds: totalMovingSeconds),
      learnedMovingSpeedKmh: learnedMoving,
      learnedOverallSpeedKmh: learnedOverall,
      reliable: reliable,
    );
  }

  double _robustAverage(List<double> sorted) {
    if (sorted.length <= 2) {
      return sorted.reduce((a, b) => a + b) / sorted.length;
    }
    final values = sorted.length >= 5
        ? sorted.sublist(1, sorted.length - 1)
        : sorted;
    return values.reduce((a, b) => a + b) / values.length;
  }
}

class BikeRideHistoryService extends ChangeNotifier {
  BikeRideHistoryService._();

  static final BikeRideHistoryService instance = BikeRideHistoryService._();
  static const int schema = 1;
  static const int maximumEntries = 20;

  final BikeRideHistoryAnalyzer _analyzer = const BikeRideHistoryAnalyzer();
  final List<BikeRideHistoryEntry> _entries = <BikeRideHistoryEntry>[];
  File? _file;
  bool _initialized = false;
  Future<void>? _initializing;

  bool get initialized => _initialized;
  List<BikeRideHistoryEntry> get entries =>
      List<BikeRideHistoryEntry>.unmodifiable(_entries);
  BikeRideHistorySummary get summary => _analyzer.summarize(_entries);

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    final pending = _initializing;
    if (pending != null) return pending;
    final operation = _initializeInternal();
    _initializing = operation;
    return operation.whenComplete(() => _initializing = null);
  }

  Future<void> _initializeInternal() async {
    final root = await getApplicationSupportDirectory();
    _file = File(
      '${root.path}${Platform.pathSeparator}bike_ride_history.json',
    );
    final file = _file!;
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          final rawEntries = map['entries'];
          if (rawEntries is List) {
            for (final raw in rawEntries.whereType<Map>()) {
              try {
                _entries.add(
                  BikeRideHistoryEntry.fromJson(
                    Map<String, dynamic>.from(raw),
                  ),
                );
              } catch (_) {
                continue;
              }
            }
          }
        }
      } catch (_) {
        _entries.clear();
      }
    }
    if (_entries.length > maximumEntries) {
      _entries.removeRange(0, _entries.length - maximumEntries);
    }
    _initialized = true;
  }

  Future<bool> recordRide({
    required List<List<MapRoutePoint>> segments,
    required double distanceMeters,
    required Duration elapsedDuration,
    required DateTime startedAt,
    required DateTime endedAt,
  }) async {
    await initialize();
    final entry = _analyzer.analyze(
      segments: segments,
      distanceMeters: distanceMeters,
      elapsedDuration: elapsedDuration,
      startedAt: startedAt,
      endedAt: endedAt,
    );
    if (entry == null) return false;
    _entries.add(entry);
    if (_entries.length > maximumEntries) {
      _entries.removeRange(0, _entries.length - maximumEntries);
    }
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> clear() async {
    await initialize();
    _entries.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final file = _file;
    if (file == null) return;
    final temp = File('${file.path}.tmp');
    final payload = <String, Object?>{
      'schema': schema,
      'entries': _entries.map((entry) => entry.toJson()).toList(growable: false),
    };
    await temp.writeAsString(jsonEncode(payload), flush: true);
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }
}
