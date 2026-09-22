import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/bike_mode_config.dart';
import '../models/bike_sensor_snapshot.dart';
import 'bike_mode_service.dart';

/// Fonte única dos dados exibidos no HUD do Modo Bike.
///
/// O simulador e a entrada ESP32 compartilham o mesmo contrato, permitindo ligar
/// a futura ponte HTTP/Bluetooth sem redesenhar o HUD.
class BikeSensorService extends ChangeNotifier {
  BikeSensorService._() {
    _bikeMode.addListener(_syncWithBikeConfig);
  }

  static final BikeSensorService instance = BikeSensorService._();

  final BikeModeService _bikeMode = BikeModeService.instance;
  Timer? _timer;
  Timer? _staleTimer;
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
      _staleTimer?.cancel();
      _staleTimer = null;
      _snapshot = config.enabled
          ? BikeSensorSnapshot(
              capturedAt: DateTime.now(),
              source: BikeSensorSource.esp32,
              connected: false,
              speedKmh: 0,
              frontTirePsi: 0,
              rearTirePsi: 0,
              sensorBatteryPercent: 0,
              tripDistanceKm: _tripDistanceKm,
            )
          : null;
      notifyListeners();
      return;
    }

    _emitSimulation(config.simulationScenario);
    _timer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => _emitSimulation(_bikeMode.config.simulationScenario),
    );
  }

  /// Entrada única para a futura ponte HTTP/Bluetooth do ESP32.
  void applyEsp32Telemetry(Map<String, dynamic> payload) {
    if (!_initialized || !_bikeMode.config.enabled) return;
    _timer?.cancel();
    _timer = null;
    final snapshot = BikeSensorSnapshot.fromEsp32Json(payload);
    _tripDistanceKm = snapshot.tripDistanceKm;
    _snapshot = snapshot;
    _staleTimer?.cancel();
    _staleTimer = Timer(const Duration(seconds: 6), () {
      final current = _snapshot;
      if (current == null || current.source != BikeSensorSource.esp32) return;
      _snapshot = BikeSensorSnapshot(
        capturedAt: current.capturedAt,
        source: BikeSensorSource.esp32,
        connected: false,
        speedKmh: 0,
        frontTirePsi: current.frontTirePsi,
        rearTirePsi: current.rearTirePsi,
        sensorBatteryPercent: current.sensorBatteryPercent,
        tripDistanceKm: current.tripDistanceKm,
        ambientTemperatureC: current.ambientTemperatureC,
      );
      notifyListeners();
    });
    notifyListeners();
  }

  void _emitSimulation(BikeSimulationScenario scenario) {
    if (!_bikeMode.config.sensorSimulationEnabled) return;
    _staleTimer?.cancel();
    _staleTimer = null;
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
