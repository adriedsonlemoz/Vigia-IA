import 'dart:io';

import 'package:flutter/services.dart';

class MapCompassReading {
  const MapCompassReading({
    required this.headingDegrees,
    required this.sensor,
    required this.recordedAt,
  });

  final double headingDegrees;
  final String sensor;
  final DateTime recordedAt;

  static MapCompassReading? fromPlatform(Object? raw) {
    if (raw is! Map) return null;
    final heading = raw['headingDegrees'];
    final sensor = raw['sensor'];
    final timestampMs = raw['timestampMs'];
    if (heading is! num || !heading.toDouble().isFinite) return null;
    if (sensor is! String || sensor.trim().isEmpty) return null;
    if (timestampMs is! num) return null;
    final normalized = ((heading.toDouble() % 360) + 360) % 360;
    return MapCompassReading(
      headingDegrees: normalized,
      sensor: sensor,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(timestampMs.toInt()),
    );
  }
}

class MapCompassService {
  const MapCompassService();

  static const EventChannel _channel = EventChannel('vigiaia/compass');

  Stream<MapCompassReading> readings() {
    if (!Platform.isAndroid) return const Stream<MapCompassReading>.empty();
    return _channel
        .receiveBroadcastStream()
        .map(MapCompassReading.fromPlatform)
        .where((reading) => reading != null)
        .cast<MapCompassReading>();
  }
}
