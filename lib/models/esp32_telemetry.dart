import 'esp32_module.dart';

enum Esp32ConnectionState { disabled, connecting, online, degraded, offline }

extension Esp32ConnectionStateLabel on Esp32ConnectionState {
  String get label => switch (this) {
        Esp32ConnectionState.disabled => 'Desativado',
        Esp32ConnectionState.connecting => 'Conectando',
        Esp32ConnectionState.online => 'Telemetria ativa',
        Esp32ConnectionState.degraded => 'Conexão instável',
        Esp32ConnectionState.offline => 'Offline',
      };
}

class Esp32EnergyTelemetry {
  const Esp32EnergyTelemetry({
    this.sourceType,
    this.batteryPresent,
    this.batteryChemistry,
    this.monitorType,
    this.batteryPercent,
    this.voltageV,
    this.currentA,
    this.powerW,
    this.charging,
    this.externalPower,
    this.batteryTemperatureC,
    this.solarVoltageV,
    this.solarCurrentA,
    this.solarPowerW,
    this.energyInWh,
    this.energyOutWh,
  });

  final String? sourceType;
  final bool? batteryPresent;
  final String? batteryChemistry;
  final String? monitorType;
  final int? batteryPercent;
  final double? voltageV;
  final double? currentA;
  final double? powerW;
  final bool? charging;
  final bool? externalPower;
  final double? batteryTemperatureC;
  final double? solarVoltageV;
  final double? solarCurrentA;
  final double? solarPowerW;
  final double? energyInWh;
  final double? energyOutWh;

  bool get hasValues =>
      sourceType != null ||
      batteryPresent != null ||
      batteryPercent != null ||
      voltageV != null ||
      currentA != null ||
      powerW != null ||
      charging != null ||
      externalPower != null ||
      batteryTemperatureC != null ||
      solarVoltageV != null ||
      solarCurrentA != null ||
      solarPowerW != null ||
      energyInWh != null ||
      energyOutWh != null;

  Map<String, Object?> toJson() => <String, Object?>{
        'sourceType': sourceType,
        'batteryPresent': batteryPresent,
        'batteryChemistry': batteryChemistry,
        'monitorType': monitorType,
        'batteryPercent': batteryPercent,
        'voltageV': voltageV,
        'currentA': currentA,
        'powerW': powerW,
        'charging': charging,
        'externalPower': externalPower,
        'batteryTemperatureC': batteryTemperatureC,
        'solarVoltageV': solarVoltageV,
        'solarCurrentA': solarCurrentA,
        'solarPowerW': solarPowerW,
        'energyInWh': energyInWh,
        'energyOutWh': energyOutWh,
      };
}

class Esp32TelemetryPacket {
  const Esp32TelemetryPacket({
    required this.moduleId,
    required this.receivedAt,
    required this.connected,
    required this.bikePayload,
    this.capturedAt,
    this.sequence,
    this.uptime,
    this.rssiDbm,
    this.batteryPercent,
    this.batteryVoltage,
    this.charging,
    this.energy,
    this.protocolVersion,
    this.firmwareVersion,
    this.reportedCapabilities = const <Esp32Capability>{},
  });

  final String moduleId;
  final DateTime receivedAt;
  final DateTime? capturedAt;
  final bool connected;
  final int? sequence;
  final Duration? uptime;
  final int? rssiDbm;
  final int? batteryPercent;
  final double? batteryVoltage;
  final bool? charging;
  final Esp32EnergyTelemetry? energy;
  final int? protocolVersion;
  final String? firmwareVersion;
  final Set<Esp32Capability> reportedCapabilities;
  final Map<String, dynamic> bikePayload;

  bool get hasBikeTelemetry {
    const keys = <String>{
      'speedKmh',
      'frontTirePsi',
      'rearTirePsi',
      'batteryPercent',
      'tripDistanceKm',
      'temperatureC',
    };
    return bikePayload.keys.any(keys.contains);
  }

  String get wifiQualityLabel {
    final rssi = rssiDbm;
    if (rssi == null) return 'Wi‑Fi sem RSSI';
    if (rssi >= -55) return 'Wi‑Fi excelente';
    if (rssi >= -67) return 'Wi‑Fi bom';
    if (rssi >= -75) return 'Wi‑Fi regular';
    return 'Wi‑Fi fraco';
  }

  Map<String, Object?> toDiagnosticJson() => <String, Object?>{
        'moduleId': moduleId,
        'receivedAt': receivedAt.toIso8601String(),
        'capturedAt': capturedAt?.toIso8601String(),
        'connected': connected,
        'sequence': sequence,
        'uptimeMs': uptime?.inMilliseconds,
        'rssiDbm': rssiDbm,
        'batteryPercent': batteryPercent,
        'batteryVoltage': batteryVoltage,
        'charging': charging,
        'energy': energy?.toJson(),
        'protocolVersion': protocolVersion,
        'firmwareVersion': firmwareVersion,
        'capabilities': reportedCapabilities.map((item) => item.name).toList()
          ..sort(),
        'bikeTelemetry': bikePayload,
      };

  factory Esp32TelemetryPacket.fromJson(
    Map<String, dynamic> json, {
    required String fallbackModuleId,
    DateTime? receivedAt,
  }) {
    final received = receivedAt ?? DateTime.now();
    final telemetry = _stringMap(json['telemetry']) ?? json;
    final bikeSensors = _stringMap(json['bikeSensors']) ??
        _stringMap(telemetry['bikeSensors']);
    final sensors = _stringMap(telemetry['sensors']) ??
        _stringMap(json['sensors']) ??
        const <String, dynamic>{};
    final hall = _stringMap(sensors['hall']) ??
        _stringMap(telemetry['hall']) ??
        const <String, dynamic>{};
    final tires = _stringMap(sensors['tirePressure']) ??
        _stringMap(telemetry['tirePressure']) ??
        const <String, dynamic>{};
    final power = _stringMap(telemetry['power']) ??
        _stringMap(json['power']) ??
        const <String, dynamic>{};
    final battery = _stringMap(power['battery']) ??
        _stringMap(telemetry['battery']) ??
        _stringMap(json['battery']) ??
        const <String, dynamic>{};
    final solar = _stringMap(power['solar']) ??
        _stringMap(telemetry['solar']) ??
        _stringMap(json['solar']) ??
        const <String, dynamic>{};
    final supply = _stringMap(power['supply']) ?? const <String, dynamic>{};
    final monitor = _stringMap(power['monitor']) ?? const <String, dynamic>{};
    final wifi = _stringMap(telemetry['wifi']) ??
        _stringMap(json['wifi']) ??
        const <String, dynamic>{};

    final bike = <String, dynamic>{};
    if (bikeSensors != null) {
      final knownNumbers = <String>[
        'speedKmh',
        'frontTirePsi',
        'rearTirePsi',
        'batteryPercent',
        'tripDistanceKm',
        'temperatureC',
      ];
      for (final key in knownNumbers) {
        _putNumber(bike, key, _firstNumber(<Object?>[bikeSensors[key]]));
      }
      if (bikeSensors['capturedAt'] is String) {
        bike['capturedAt'] = bikeSensors['capturedAt'];
      }
      bike['connected'] = _firstBool(<Object?>[bikeSensors['connected']]) ?? true;
      bike['source'] = 'esp32';
      bike['moduleId'] = bikeSensors['moduleId'] ??
          telemetry['moduleId'] ??
          json['moduleId'];
    } else {
      _putNumber(
        bike,
        'speedKmh',
        _firstNumber(<Object?>[
          telemetry['speedKmh'],
          sensors['speedKmh'],
          hall['speedKmh'],
        ]),
      );
      _putNumber(
        bike,
        'frontTirePsi',
        _firstNumber(<Object?>[
          telemetry['frontTirePsi'],
          sensors['frontTirePsi'],
          tires['frontPsi'],
          tires['frontTirePsi'],
        ]),
      );
      _putNumber(
        bike,
        'rearTirePsi',
        _firstNumber(<Object?>[
          telemetry['rearTirePsi'],
          sensors['rearTirePsi'],
          tires['rearPsi'],
          tires['rearTirePsi'],
        ]),
      );
      _putNumber(
        bike,
        'batteryPercent',
        _firstNumber(<Object?>[
          telemetry['batteryPercent'],
          sensors['batteryPercent'],
          power['moduleBatteryPercent'],
          if (battery.isEmpty) power['batteryPercent'],
          if (battery.isEmpty) power['percent'],
        ]),
      );
      _putNumber(
        bike,
        'tripDistanceKm',
        _firstNumber(<Object?>[
          telemetry['tripDistanceKm'],
          sensors['tripDistanceKm'],
          hall['tripDistanceKm'],
        ]),
      );
      _putNumber(
        bike,
        'temperatureC',
        _firstNumber(<Object?>[
          telemetry['temperatureC'],
          telemetry['ambientTemperatureC'],
          sensors['temperatureC'],
          sensors['ambientTemperatureC'],
        ]),
      );
      bike['connected'] = _firstBool(<Object?>[telemetry['connected']]) ?? true;
      bike['source'] = 'esp32';
      bike['moduleId'] = telemetry['moduleId'] ?? json['moduleId'];
      final captured = telemetry['capturedAt'] ?? json['capturedAt'];
      if (captured is String) bike['capturedAt'] = captured;
    }

    final rawCapabilities = telemetry['capabilities'] ?? json['capabilities'];
    final capabilities = <Esp32Capability>{};
    if (rawCapabilities is List) {
      for (final raw in rawCapabilities) {
        final name = raw?.toString();
        for (final capability in Esp32Capability.values) {
          if (capability.name == name) capabilities.add(capability);
        }
      }
    }

    final capturedRaw = telemetry['capturedAt'] ?? json['capturedAt'];
    final uptimeMs = _firstNumber(<Object?>[
      telemetry['uptimeMs'],
      json['uptimeMs'],
    ]);
    final uptimeSeconds = _firstNumber(<Object?>[
      telemetry['uptimeSeconds'],
      json['uptimeSeconds'],
      telemetry['uptime'],
      json['uptime'],
    ]);
    final moduleBatteryPercentNumber = _firstNumber(<Object?>[
      telemetry['batteryPercent'],
      power['moduleBatteryPercent'],
      if (battery.isEmpty) power['batteryPercent'],
      if (battery.isEmpty) power['percent'],
      bike['batteryPercent'],
    ]);
    final moduleBatteryVoltage = _firstNumber(<Object?>[
      telemetry['batteryVoltage'],
      power['moduleBatteryVoltage'],
      if (battery.isEmpty) power['batteryVoltage'],
      if (battery.isEmpty) power['voltageV'],
      if (battery.isEmpty) power['voltage'],
    ])?.toDouble();
    final energyBatteryPercentNumber = _firstNumber(<Object?>[
      battery['percent'],
      battery['batteryPercent'],
      power['systemBatteryPercent'],
    ]);
    final voltage = _firstNumber(<Object?>[
      battery['voltageV'],
      battery['voltage'],
      power['systemBatteryVoltageV'],
    ])?.toDouble();
    final current = _firstNumber(<Object?>[
      battery['currentA'],
      battery['current'],
      power['systemBatteryCurrentA'],
    ])?.toDouble();
    final explicitPower = _firstNumber(<Object?>[
      battery['powerW'],
      power['batteryPowerW'],
      power['powerW'],
      power['watts'],
    ])?.toDouble();
    final charging = _firstBool(<Object?>[
      telemetry['charging'],
      power['moduleCharging'],
      if (battery.isEmpty) power['charging'],
      power['externalPower'],
    ]);
    final energyCharging = _firstBool(<Object?>[
      battery['charging'],
      power['systemBatteryCharging'],
    ]);
    final externalPower = _firstBool(<Object?>[
      power['externalPower'],
      supply['externalPower'],
      telemetry['externalPower'],
    ]);
    final modulePercent =
        moduleBatteryPercentNumber?.toInt().clamp(0, 100).toInt();
    final energyPercent =
        energyBatteryPercentNumber?.toInt().clamp(0, 100).toInt();
    final solarVoltage = _firstNumber(<Object?>[
      solar['voltageV'],
      solar['voltage'],
      power['solarVoltageV'],
    ])?.toDouble();
    final solarCurrent = _firstNumber(<Object?>[
      solar['currentA'],
      solar['current'],
      power['solarCurrentA'],
    ])?.toDouble();
    final solarPower = _firstNumber(<Object?>[
      solar['powerW'],
      solar['watts'],
      power['solarPowerW'],
    ])?.toDouble();
    final energy = Esp32EnergyTelemetry(
      sourceType: _firstString(<Object?>[
        supply['type'],
        supply['source'],
        power['sourceType'],
        power['source'],
      ]),
      batteryPresent: _firstBool(<Object?>[
            battery['present'],
            power['batteryPresent'],
          ]) ??
          (voltage != null || energyPercent != null ? true : null),
      batteryChemistry: _firstString(<Object?>[
        battery['chemistry'],
        power['batteryChemistry'],
      ]),
      monitorType: _firstString(<Object?>[
        monitor['type'],
        monitor['model'],
        power['monitorType'],
        power['sensorModel'],
      ]),
      batteryPercent: energyPercent,
      voltageV: voltage,
      currentA: current,
      powerW: explicitPower ??
          (voltage != null && current != null ? voltage * current : null),
      charging: energyCharging,
      externalPower: externalPower,
      batteryTemperatureC: _firstNumber(<Object?>[
        battery['temperatureC'],
        power['batteryTemperatureC'],
      ])?.toDouble(),
      solarVoltageV: solarVoltage,
      solarCurrentA: solarCurrent,
      solarPowerW: solarPower ??
          (solarVoltage != null && solarCurrent != null
              ? solarVoltage * solarCurrent
              : null),
      energyInWh: _firstNumber(<Object?>[
        power['energyInWh'],
        battery['energyInWh'],
      ])?.toDouble(),
      energyOutWh: _firstNumber(<Object?>[
        power['energyOutWh'],
        battery['energyOutWh'],
      ])?.toDouble(),
    );
    final moduleId = (telemetry['moduleId'] ?? json['moduleId'])?.toString();

    return Esp32TelemetryPacket(
      moduleId: moduleId == null || moduleId.trim().isEmpty
          ? fallbackModuleId
          : moduleId,
      receivedAt: received,
      capturedAt: capturedRaw is String ? DateTime.tryParse(capturedRaw) : null,
      connected: _firstBool(<Object?>[
            telemetry['connected'],
            json['connected'],
            bike['connected'],
          ]) ??
          true,
      sequence: _firstNumber(<Object?>[
        telemetry['sequence'],
        json['sequence'],
        telemetry['seq'],
        json['seq'],
      ])?.toInt(),
      uptime: uptimeMs != null
          ? Duration(
              milliseconds: uptimeMs.toInt().clamp(0, 0x7fffffff).toInt(),
            )
          : uptimeSeconds == null
              ? null
              : Duration(
                  seconds:
                      uptimeSeconds.toInt().clamp(0, 0x7fffffff).toInt(),
                ),
      rssiDbm: _firstNumber(<Object?>[
        telemetry['rssiDbm'],
        json['rssiDbm'],
        wifi['rssiDbm'],
        wifi['rssi'],
      ])?.toInt(),
      batteryPercent: modulePercent,
      batteryVoltage: moduleBatteryVoltage,
      charging: charging,
      energy: energy.hasValues ? energy : null,
      protocolVersion: _firstNumber(<Object?>[
        telemetry['protocolVersion'],
        json['protocolVersion'],
      ])?.toInt(),
      firmwareVersion: (telemetry['firmwareVersion'] ??
              telemetry['firmware'] ??
              json['firmwareVersion'] ??
              json['firmware'])
          ?.toString(),
      reportedCapabilities: Set<Esp32Capability>.unmodifiable(capabilities),
      bikePayload: Map<String, dynamic>.unmodifiable(bike),
    );
  }
}

class Esp32RuntimeState {
  const Esp32RuntimeState({
    required this.moduleId,
    required this.connectionState,
    this.lastAttemptAt,
    this.lastSuccessAt,
    this.nextRetryAt,
    this.latency,
    this.endpointPath,
    this.consecutiveFailures = 0,
    this.error,
    this.packet,
  });

  final String moduleId;
  final Esp32ConnectionState connectionState;
  final DateTime? lastAttemptAt;
  final DateTime? lastSuccessAt;
  final DateTime? nextRetryAt;
  final Duration? latency;
  final String? endpointPath;
  final int consecutiveFailures;
  final String? error;
  final Esp32TelemetryPacket? packet;

  bool get online => connectionState == Esp32ConnectionState.online;

  Map<String, Object?> toDiagnosticJson() => <String, Object?>{
        'moduleId': moduleId,
        'state': connectionState.name,
        'lastAttemptAt': lastAttemptAt?.toIso8601String(),
        'lastSuccessAt': lastSuccessAt?.toIso8601String(),
        'nextRetryAt': nextRetryAt?.toIso8601String(),
        'latencyMs': latency?.inMilliseconds,
        'endpointPath': endpointPath,
        'consecutiveFailures': consecutiveFailures,
        'error': error,
        'packet': packet?.toDiagnosticJson(),
      };
}

Map<String, dynamic>? _stringMap(Object? value) {
  if (value is! Map) return null;
  return value.map((key, item) => MapEntry(key.toString(), item));
}

num? _firstNumber(List<Object?> values) {
  for (final value in values) {
    if (value is num) return value;
    if (value is String) {
      final parsed = num.tryParse(value.replaceAll(',', '.'));
      if (parsed != null) return parsed;
    }
  }
  return null;
}

String? _firstString(List<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

bool? _firstBool(List<Object?> values) {
  for (final value in values) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
  }
  return null;
}

void _putNumber(Map<String, dynamic> target, String key, num? value) {
  if (value != null) target[key] = value;
}
