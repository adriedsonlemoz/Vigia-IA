import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/bike_mode_config.dart';
import '../models/bike_sensor_snapshot.dart';
import 'bike_mode_service.dart';

/// Fonte única dos dados exibidos no HUD do Modo Bike.
///
/// Nesta etapa apenas o simulador está conectado. O contrato foi separado da UI
/// para que uma fonte ESP32 possa substituir o simulador posteriormente sem
/// redesenhar o HUD.
class BikeSensorService extends ChangeNotifier {
  BikeSensorService._() {
    _bikeMode.addListener(_syncWithBikeConfig);
  }

  static final BikeSensorService instance = BikeSensorService._();

  final BikeModeService _bikeMode = BikeModeService.instance;
  Timer? _timer;
  BikeSensorSnapshot? _snapshot;
  bool _initialized = false;
  int _tick = 0;
  double _tripDistanceKm = 0;

  BikeSensorSnapshot? get snapshot => _snapshot;

  Future<void> initialize() async {
    if (_initialized) return;
    await _bikeMode.initialize();
    _initialized = true;
    _syncWithBikeConfig();
  }

  void _syncWithBikeConfig() {
    final config = _bikeMode.config;
    if (!config.sensorSimulationEnabled) {
      _timer?.cancel();
      _timer = null;
      _snapshot = null;
      notifyListeners();
      return;
    }

    _emitSimulation(config.simulationScenario);
    _timer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => _emitSimulation(_bikeMode.config.simulationScenario),
    );
  }

  void _emitSimulation(BikeSimulationScenario scenario) {
    if (!_bikeMode.config.sensorSimulationEnabled) return;
    _tick++;
    final wave = math.sin(_tick / 3.2);
    final speed = switch (scenario) {
      BikeSimulationScenario.disconnected => 0.0,
      _ => (24.0 + (wave * 3.5)).clamp(0.0, 42.0).toDouble(),
    };
    _tripDistanceKm += speed / 3600.0;

    final frontPsi = switch (scenario) {
      BikeSimulationScenario.frontTireLow => 24.0,
      _ => 42.0 + (wave * 0.4),
    };
    final rearPsi = switch (scenario) {
      BikeSimulationScenario.rearTireLow => 26.0,
      _ => 45.0 - (wave * 0.4),
    };
    final battery = switch (scenario) {
      BikeSimulationScenario.sensorBatteryLow => 8,
      _ => 82,
    };
    final connected = scenario != BikeSimulationScenario.disconnected;

    _snapshot = BikeSensorSnapshot(
      capturedAt: DateTime.now(),
      source: BikeSensorSource.simulator,
      connected: connected,
      speedKmh: speed,
      frontTirePsi: frontPsi,
      rearTirePsi: rearPsi,
      sensorBatteryPercent: battery,
      tripDistanceKm: _tripDistanceKm,
      ambientTemperatureC: 25.0 + (wave * 1.5),
    );
    notifyListeners();
  }
}
