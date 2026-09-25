import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/bike_mode_config.dart';
import '../models/bike_sensor_snapshot.dart';
import 'bike_mode_service.dart';

/// Fonte única dos dados exibidos no HUD do Modo Bike.
///
/// O simulador e a entrada ESP32 compartilham o mesmo contrato. A coleção por
/// módulo já permite conectar vários ESP32 sem trocar o contrato do HUD; a
/// ponte de transporte escolhe/combina esses módulos antes de promover um
/// snapshot para [snapshot].
class BikeSensorService extends ChangeNotifier {
  BikeSensorService._() {
    _bikeMode.addListener(_syncWithBikeConfig);
  }

  static final BikeSensorService instance = BikeSensorService._();

  final BikeModeService _bikeMode = BikeModeService.instance;
  final Map<String, BikeSensorSnapshot> _moduleSnapshots =
      <String, BikeSensorSnapshot>{};
  final Map<String, Timer> _staleTimers = <String, Timer>{};
  Timer? _timer;
  BikeSensorSnapshot? _snapshot;
  bool _initialized = false;
  int _tick = 0;
  double _tripDistanceKm = 0;
  String? _primaryModuleId;

  BikeSensorSnapshot? get snapshot => _snapshot;

  Map<String, BikeSensorSnapshot> get moduleSnapshots =>
      Map<String, BikeSensorSnapshot>.unmodifiable(_moduleSnapshots);

  String? get primaryModuleId => _primaryModuleId;

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
      if (!config.enabled) {
        _cancelStaleTimers();
        _moduleSnapshots.clear();
        _primaryModuleId = null;
        _snapshot = null;
      } else if (_moduleSnapshots.isEmpty) {
        _snapshot = BikeSensorSnapshot(
          capturedAt: DateTime.now(),
          source: BikeSensorSource.esp32,
          connected: false,
          speedKmh: 0,
          frontTirePsi: 0,
          rearTirePsi: 0,
          sensorBatteryPercent: 0,
          tripDistanceKm: _tripDistanceKm,
        );
      }
      notifyListeners();
      return;
    }

    _cancelStaleTimers();
    _moduleSnapshots.clear();
    _primaryModuleId = null;
    _emitSimulation(config.simulationScenario);
    _timer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => _emitSimulation(_bikeMode.config.simulationScenario),
    );
  }

  /// Entrada compartilhada pela futura ponte HTTP/WebSocket/Bluetooth do ESP32.
  ///
  /// Cada módulo mantém seu próprio snapshot e timeout. O timeout acompanha o
  /// intervalo configurado, evitando marcar como offline um módulo que envia a
  /// cada 5 segundos.
  void applyEsp32Telemetry(
    Map<String, dynamic> payload, {
    String moduleId = 'primary',
    double minimumTirePressurePsi = 30,
    double maximumTemperatureC = 65,
    int telemetryIntervalMs = 1000,
  }) {
    if (!_initialized || !_bikeMode.config.enabled) return;
    _timer?.cancel();
    _timer = null;
    final snapshot = BikeSensorSnapshot.fromEsp32Json(
      payload,
      moduleId: moduleId,
      minimumTirePressurePsi: minimumTirePressurePsi,
      maximumTemperatureC: maximumTemperatureC,
    );
    _tripDistanceKm = math.max(_tripDistanceKm, snapshot.tripDistanceKm).toDouble();
    _moduleSnapshots[moduleId] = snapshot;
    _primaryModuleId = moduleId;
    _snapshot = snapshot;

    _staleTimers.remove(moduleId)?.cancel();
    final staleAfter = Duration(
      milliseconds: math.max(6000, telemetryIntervalMs * 3).toInt(),
    );
    _staleTimers[moduleId] = Timer(staleAfter, () {
      final current = _moduleSnapshots[moduleId];
      if (current == null || current.source != BikeSensorSource.esp32) return;
      final disconnected = BikeSensorSnapshot(
        capturedAt: current.capturedAt,
        source: BikeSensorSource.esp32,
        connected: false,
        speedKmh: 0,
        frontTirePsi: current.frontTirePsi,
        rearTirePsi: current.rearTirePsi,
        sensorBatteryPercent: current.sensorBatteryPercent,
        tripDistanceKm: current.tripDistanceKm,
        ambientTemperatureC: current.ambientTemperatureC,
        moduleId: current.moduleId,
        minimumTirePressurePsi: current.minimumTirePressurePsi,
        maximumTemperatureC: current.maximumTemperatureC,
      );
      _moduleSnapshots[moduleId] = disconnected;
      if (_primaryModuleId == moduleId) _snapshot = disconnected;
      notifyListeners();
    });
    notifyListeners();
  }

  void _cancelStaleTimers() {
    for (final timer in _staleTimers.values) {
      timer.cancel();
    }
    _staleTimers.clear();
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
