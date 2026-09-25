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
          speedAvailable: false,
          tirePressureAvailable: false,
          frontTirePressureAvailable: false,
          rearTirePressureAvailable: false,
          batteryAvailable: false,
          temperatureAvailable: false,
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

  /// Entrada compartilhada pela ponte HTTP atual e por futuros transportes WebSocket/Bluetooth.
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
    if (!_initialized ||
        !_bikeMode.config.enabled ||
        _bikeMode.config.sensorSimulationEnabled) {
      return;
    }
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
    _rebuildEsp32Snapshot();

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
        speedAvailable: current.speedAvailable,
        tirePressureAvailable: current.tirePressureAvailable,
        frontTirePressureAvailable: current.frontTirePressureAvailable,
        rearTirePressureAvailable: current.rearTirePressureAvailable,
        batteryAvailable: current.batteryAvailable,
        temperatureAvailable: current.temperatureAvailable,
      );
      _moduleSnapshots[moduleId] = disconnected;
      _rebuildEsp32Snapshot();
      notifyListeners();
    });
    notifyListeners();
  }

  void markEsp32ModuleDisconnected(String moduleId) {
    final current = _moduleSnapshots[moduleId];
    if (current == null || current.source != BikeSensorSource.esp32) return;
    _staleTimers.remove(moduleId)?.cancel();
    _moduleSnapshots[moduleId] = BikeSensorSnapshot(
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
      speedAvailable: current.speedAvailable,
      tirePressureAvailable: current.tirePressureAvailable,
      frontTirePressureAvailable: current.frontTirePressureAvailable,
      rearTirePressureAvailable: current.rearTirePressureAvailable,
      batteryAvailable: current.batteryAvailable,
      temperatureAvailable: current.temperatureAvailable,
    );
    _rebuildEsp32Snapshot();
    notifyListeners();
  }

  void removeEsp32Module(String moduleId) {
    _staleTimers.remove(moduleId)?.cancel();
    if (_moduleSnapshots.remove(moduleId) == null) return;
    _rebuildEsp32Snapshot();
    notifyListeners();
  }

  void _rebuildEsp32Snapshot() {
    final snapshots = _moduleSnapshots.values
        .where((item) => item.source == BikeSensorSource.esp32)
        .toList(growable: false);
    if (snapshots.isEmpty) {
      _primaryModuleId = null;
      _snapshot = BikeSensorSnapshot(
        capturedAt: DateTime.now(),
        source: BikeSensorSource.esp32,
        connected: false,
        speedKmh: 0,
        frontTirePsi: 0,
        rearTirePsi: 0,
        sensorBatteryPercent: 0,
        tripDistanceKm: _tripDistanceKm,
        speedAvailable: false,
        tirePressureAvailable: false,
        frontTirePressureAvailable: false,
        rearTirePressureAvailable: false,
        batteryAvailable: false,
        temperatureAvailable: false,
      );
      return;
    }

    final connected = snapshots.where((item) => item.connected).toList();
    final candidates = connected.isEmpty ? snapshots : connected;
    candidates.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    final newest = candidates.first;
    final speed = _latestAvailable(candidates, (item) => item.speedAvailable);
    final frontPressure = _latestAvailable(
      candidates,
      (item) => item.frontTirePressureAvailable,
    );
    final rearPressure = _latestAvailable(
      candidates,
      (item) => item.rearTirePressureAvailable,
    );
    final temperature = _latestAvailable(
      candidates,
      (item) => item.temperatureAvailable,
    );
    final batteries = candidates.where((item) => item.batteryAvailable).toList();
    final minimumBattery = batteries.isEmpty
        ? null
        : batteries
            .map((item) => item.sensorBatteryPercent)
            .reduce((a, b) => math.min(a, b).toInt());
    final pressureLimits = candidates
        .where((item) => item.tirePressureAvailable)
        .map((item) => item.minimumTirePressurePsi)
        .toList(growable: false);
    final temperatureLimits = candidates
        .where((item) => item.temperatureAvailable)
        .map((item) => item.maximumTemperatureC)
        .toList(growable: false);

    _primaryModuleId = connected.length == 1 ? connected.first.moduleId : null;
    _snapshot = BikeSensorSnapshot(
      capturedAt: newest.capturedAt,
      source: BikeSensorSource.esp32,
      connected: connected.isNotEmpty,
      speedKmh: speed?.speedKmh ?? 0,
      frontTirePsi: frontPressure?.frontTirePsi ?? 0,
      rearTirePsi: rearPressure?.rearTirePsi ?? 0,
      sensorBatteryPercent: minimumBattery ?? 0,
      tripDistanceKm: snapshots
          .map((item) => item.tripDistanceKm)
          .fold<double>(
            _tripDistanceKm,
            (previous, value) => math.max(previous, value).toDouble(),
          ),
      ambientTemperatureC: temperature?.ambientTemperatureC,
      moduleId: connected.length == 1 ? connected.first.moduleId : 'multiple',
      minimumTirePressurePsi: pressureLimits.isEmpty
          ? 30
          : pressureLimits.reduce((a, b) => math.max(a, b).toDouble()),
      maximumTemperatureC: temperatureLimits.isEmpty
          ? 65
          : temperatureLimits.reduce((a, b) => math.min(a, b).toDouble()),
      speedAvailable: speed != null,
      tirePressureAvailable: frontPressure != null || rearPressure != null,
      frontTirePressureAvailable: frontPressure != null,
      rearTirePressureAvailable: rearPressure != null,
      batteryAvailable: minimumBattery != null,
      temperatureAvailable: temperature != null,
    );
  }

  BikeSensorSnapshot? _latestAvailable(
    List<BikeSensorSnapshot> snapshots,
    bool Function(BikeSensorSnapshot snapshot) predicate,
  ) {
    for (final snapshot in snapshots) {
      if (predicate(snapshot)) return snapshot;
    }
    return null;
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
