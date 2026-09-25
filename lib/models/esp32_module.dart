import 'dart:math' as math;

import 'camera_endpoint.dart';

enum Esp32ModulePosition {
  unspecified,
  front,
  rear,
  handlebar,
  box,
  helmet,
  trailer,
  environment,
  custom,
}

extension Esp32ModulePositionLabel on Esp32ModulePosition {
  String get label => switch (this) {
        Esp32ModulePosition.unspecified => 'Não definida',
        Esp32ModulePosition.front => 'Dianteiro',
        Esp32ModulePosition.rear => 'Traseiro',
        Esp32ModulePosition.handlebar => 'Guidão',
        Esp32ModulePosition.box => 'Caixa/bagageiro',
        Esp32ModulePosition.helmet => 'Capacete',
        Esp32ModulePosition.trailer => 'Reboque',
        Esp32ModulePosition.environment => 'Ambiente',
        Esp32ModulePosition.custom => 'Personalizada',
      };
}

enum Esp32Capability {
  camera,
  temperature,
  hallSpeed,
  tirePressure,
  battery,
  energy,
  mmWave,
  thermal,
  tof,
  ultrasonic,
  ambient,
  gps,
  light,
  actuator,
}

extension Esp32CapabilityLabel on Esp32Capability {
  String get label => switch (this) {
        Esp32Capability.camera => 'Câmera',
        Esp32Capability.temperature => 'Temperatura',
        Esp32Capability.hallSpeed => 'Hall',
        Esp32Capability.tirePressure => 'Pneus',
        Esp32Capability.battery => 'Bateria do módulo',
        Esp32Capability.energy => 'Energia',
        Esp32Capability.mmWave => 'mmWave',
        Esp32Capability.thermal => 'Térmico',
        Esp32Capability.tof => 'ToF',
        Esp32Capability.ultrasonic => 'Ultrassom',
        Esp32Capability.ambient => 'Ambiente',
        Esp32Capability.gps => 'GPS',
        Esp32Capability.light => 'Luz',
        Esp32Capability.actuator => 'Atuadores',
      };
}

enum Esp32PowerSupplyType {
  auto,
  usbPowerBank,
  usbAdapter,
  systemBattery,
  other,
}

extension Esp32PowerSupplyTypeLabel on Esp32PowerSupplyType {
  String get label => switch (this) {
        Esp32PowerSupplyType.auto => 'Detectar automaticamente',
        Esp32PowerSupplyType.usbPowerBank => 'Power bank USB',
        Esp32PowerSupplyType.usbAdapter => 'Tomada / fonte USB',
        Esp32PowerSupplyType.systemBattery => 'Bateria do sistema',
        Esp32PowerSupplyType.other => 'Outra alimentação',
      };
}

enum Esp32BatteryChemistry { none, leadAcid, lifepo4, other }

extension Esp32BatteryChemistryLabel on Esp32BatteryChemistry {
  String get label => switch (this) {
        Esp32BatteryChemistry.none => 'Sem bateria monitorada',
        Esp32BatteryChemistry.leadAcid => 'Chumbo-ácido',
        Esp32BatteryChemistry.lifepo4 => 'LiFePO₄',
        Esp32BatteryChemistry.other => 'Outra bateria',
      };
}

enum Esp32PowerMonitorType { automatic, voltageDivider, ina219, ina226, smartBms }

extension Esp32PowerMonitorTypeLabel on Esp32PowerMonitorType {
  String get label => switch (this) {
        Esp32PowerMonitorType.automatic => 'Detectar pelo firmware',
        Esp32PowerMonitorType.voltageDivider => 'Divisor de tensão',
        Esp32PowerMonitorType.ina219 => 'INA219',
        Esp32PowerMonitorType.ina226 => 'INA226',
        Esp32PowerMonitorType.smartBms => 'BMS com telemetria',
      };
}

class Esp32Module {
  const Esp32Module({
    required this.id,
    required this.name,
    this.address,
    this.accessKey,
    this.enabled = true,
    this.position = Esp32ModulePosition.unspecified,
    this.customPositionLabel,
    this.capabilities = const <Esp32Capability>{
      Esp32Capability.temperature,
      Esp32Capability.hallSpeed,
      Esp32Capability.tirePressure,
      Esp32Capability.battery,
    },
    this.wheelCircumferenceMm = 2100,
    this.hallMagnets = 1,
    this.minimumTirePressurePsi = 30,
    this.maximumTemperatureC = 65,
    this.powerSupplyType = Esp32PowerSupplyType.auto,
    this.batteryChemistry = Esp32BatteryChemistry.none,
    this.powerMonitorType = Esp32PowerMonitorType.automatic,
    this.batteryNominalVoltageV = 12,
    this.batteryCapacityAh = 7,
    this.lowBatteryPercent = 25,
    this.criticalBatteryPercent = 10,
    this.monitorSolarInput = false,
    this.telemetryIntervalMs = 1000,
    this.protocolVersion = 1,
  });

  final String id;
  final String name;
  final String? address;
  final String? accessKey;
  final bool enabled;
  final Esp32ModulePosition position;
  final String? customPositionLabel;
  final Set<Esp32Capability> capabilities;
  final double wheelCircumferenceMm;
  final int hallMagnets;
  final double minimumTirePressurePsi;
  final double maximumTemperatureC;
  final Esp32PowerSupplyType powerSupplyType;
  final Esp32BatteryChemistry batteryChemistry;
  final Esp32PowerMonitorType powerMonitorType;
  final double batteryNominalVoltageV;
  final double batteryCapacityAh;
  final int lowBatteryPercent;
  final int criticalBatteryPercent;
  final bool monitorSolarInput;
  final int telemetryIntervalMs;
  final int protocolVersion;

  bool supports(Esp32Capability capability) => capabilities.contains(capability);

  bool get cameraEnabled => supports(Esp32Capability.camera);
  bool get temperatureSensorEnabled => supports(Esp32Capability.temperature);
  bool get hallSensorEnabled => supports(Esp32Capability.hallSpeed);
  bool get tirePressureEnabled => supports(Esp32Capability.tirePressure);
  bool get energyMonitoringEnabled => supports(Esp32Capability.energy);
  bool get externalBatteryConfigured =>
      energyMonitoringEnabled && batteryChemistry != Esp32BatteryChemistry.none;

  String get positionLabel {
    final custom = customPositionLabel?.trim() ?? '';
    if (position == Esp32ModulePosition.custom && custom.isNotEmpty) {
      return custom;
    }
    return position.label;
  }

  String get energyProfileLabel {
    if (!energyMonitoringEnabled) return 'Sem monitor de energia';
    if (externalBatteryConfigured) {
      return '${batteryChemistry.label} · ${batteryNominalVoltageV.toStringAsFixed(batteryNominalVoltageV % 1 == 0 ? 0 : 1)} V';
    }
    return powerSupplyType.label;
  }

  double get suggestedLowVoltageV => switch (batteryChemistry) {
        Esp32BatteryChemistry.leadAcid => batteryNominalVoltageV * (12.1 / 12.0),
        Esp32BatteryChemistry.lifepo4 => batteryNominalVoltageV * (12.8 / 12.8),
        Esp32BatteryChemistry.other => batteryNominalVoltageV * 0.90,
        Esp32BatteryChemistry.none => 0,
      };

  double get suggestedCriticalVoltageV => switch (batteryChemistry) {
        Esp32BatteryChemistry.leadAcid => batteryNominalVoltageV * (11.8 / 12.0),
        Esp32BatteryChemistry.lifepo4 => batteryNominalVoltageV * (12.0 / 12.8),
        Esp32BatteryChemistry.other => batteryNominalVoltageV * 0.85,
        Esp32BatteryChemistry.none => 0,
      };

  Duration get staleAfter => Duration(
        milliseconds: math.max(6000, telemetryIntervalMs * 3).toInt(),
      );

  Esp32Module copyWith({
    String? name,
    String? address,
    String? accessKey,
    bool? enabled,
    Esp32ModulePosition? position,
    String? customPositionLabel,
    Set<Esp32Capability>? capabilities,
    double? wheelCircumferenceMm,
    int? hallMagnets,
    double? minimumTirePressurePsi,
    double? maximumTemperatureC,
    Esp32PowerSupplyType? powerSupplyType,
    Esp32BatteryChemistry? batteryChemistry,
    Esp32PowerMonitorType? powerMonitorType,
    double? batteryNominalVoltageV,
    double? batteryCapacityAh,
    int? lowBatteryPercent,
    int? criticalBatteryPercent,
    bool? monitorSolarInput,
    int? telemetryIntervalMs,
    int? protocolVersion,
  }) =>
      Esp32Module(
        id: id,
        name: name ?? this.name,
        address: address ?? this.address,
        accessKey: accessKey ?? this.accessKey,
        enabled: enabled ?? this.enabled,
        position: position ?? this.position,
        customPositionLabel: customPositionLabel ?? this.customPositionLabel,
        capabilities: capabilities ?? this.capabilities,
        wheelCircumferenceMm:
            wheelCircumferenceMm ?? this.wheelCircumferenceMm,
        hallMagnets: hallMagnets ?? this.hallMagnets,
        minimumTirePressurePsi:
            minimumTirePressurePsi ?? this.minimumTirePressurePsi,
        maximumTemperatureC: maximumTemperatureC ?? this.maximumTemperatureC,
        powerSupplyType: powerSupplyType ?? this.powerSupplyType,
        batteryChemistry: batteryChemistry ?? this.batteryChemistry,
        powerMonitorType: powerMonitorType ?? this.powerMonitorType,
        batteryNominalVoltageV:
            batteryNominalVoltageV ?? this.batteryNominalVoltageV,
        batteryCapacityAh: batteryCapacityAh ?? this.batteryCapacityAh,
        lowBatteryPercent: lowBatteryPercent ?? this.lowBatteryPercent,
        criticalBatteryPercent:
            criticalBatteryPercent ?? this.criticalBatteryPercent,
        monitorSolarInput: monitorSolarInput ?? this.monitorSolarInput,
        telemetryIntervalMs: telemetryIntervalMs ?? this.telemetryIntervalMs,
        protocolVersion: protocolVersion ?? this.protocolVersion,
      );

  CameraEndpoint toCameraEndpoint() => CameraEndpoint(
        id: id,
        name: name,
        type: CameraEndpointType.esp32,
        address: address,
        accessKey: accessKey,
        enabled: enabled,
        esp32CameraEnabled: cameraEnabled,
        temperatureSensorEnabled: temperatureSensorEnabled,
        hallSensorEnabled: hallSensorEnabled,
        tirePressureEnabled: tirePressureEnabled,
        wheelCircumferenceMm: wheelCircumferenceMm,
        hallMagnets: hallMagnets,
        minimumTirePressurePsi: minimumTirePressurePsi,
        maximumTemperatureC: maximumTemperatureC,
        telemetryIntervalMs: telemetryIntervalMs,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'address': address,
        'accessKey': accessKey,
        'enabled': enabled,
        'position': position.name,
        'customPositionLabel': customPositionLabel,
        'capabilities': capabilities.map((item) => item.name).toList()..sort(),
        'wheelCircumferenceMm': wheelCircumferenceMm,
        'hallMagnets': hallMagnets,
        'minimumTirePressurePsi': minimumTirePressurePsi,
        'maximumTemperatureC': maximumTemperatureC,
        'powerSupplyType': powerSupplyType.name,
        'batteryChemistry': batteryChemistry.name,
        'powerMonitorType': powerMonitorType.name,
        'batteryNominalVoltageV': batteryNominalVoltageV,
        'batteryCapacityAh': batteryCapacityAh,
        'lowBatteryPercent': lowBatteryPercent,
        'criticalBatteryPercent': criticalBatteryPercent,
        'monitorSolarInput': monitorSolarInput,
        'telemetryIntervalMs': telemetryIntervalMs,
        'protocolVersion': protocolVersion,
      };

  Map<String, Object?> toConfigurationJson() => <String, Object?>{
        'protocolVersion': protocolVersion,
        'moduleId': id,
        'name': name,
        'position': <String, Object?>{
          'type': position.name,
          'label': positionLabel,
        },
        'telemetryIntervalMs': telemetryIntervalMs,
        'capabilities': capabilities.map((item) => item.name).toList()..sort(),
        'camera': <String, Object?>{'enabled': cameraEnabled},
        'temperature': <String, Object?>{
          'enabled': temperatureSensorEnabled,
          'maximumC': maximumTemperatureC,
        },
        'hall': <String, Object?>{
          'enabled': hallSensorEnabled,
          'wheelCircumferenceMm': wheelCircumferenceMm,
          'magnets': hallMagnets,
        },
        'tirePressure': <String, Object?>{
          'enabled': tirePressureEnabled,
          'minimumPsi': minimumTirePressurePsi,
        },
        if (energyMonitoringEnabled)
          'energy': <String, Object?>{
          'enabled': true,
          'moduleSupply': powerSupplyType.name,
          'monitor': powerMonitorType.name,
          'battery': <String, Object?>{
            'enabled': externalBatteryConfigured,
            'chemistry': batteryChemistry.name,
            'nominalVoltageV': batteryNominalVoltageV,
            'capacityAh': batteryCapacityAh,
            'warningPercent': lowBatteryPercent,
            'criticalPercent': criticalBatteryPercent,
            'suggestedWarningVoltageV': suggestedLowVoltageV,
            'suggestedCriticalVoltageV': suggestedCriticalVoltageV,
          },
          'solar': <String, Object?>{'enabled': monitorSolarInput},
        },
      };

  factory Esp32Module.fromJson(Map<String, dynamic> json) {
    final rawCapabilities = json['capabilities'];
    final parsedCapabilities = <Esp32Capability>{};
    if (rawCapabilities is List) {
      for (final name in rawCapabilities.whereType<String>()) {
        for (final capability in Esp32Capability.values) {
          if (capability.name == name) parsedCapabilities.add(capability);
        }
      }
    } else {
      parsedCapabilities.addAll(const <Esp32Capability>{
        Esp32Capability.temperature,
        Esp32Capability.hallSpeed,
        Esp32Capability.tirePressure,
        Esp32Capability.battery,
      });
    }
    final positionName = json['position'] as String?;
    final supplyName = json['powerSupplyType'] as String?;
    final chemistryName = json['batteryChemistry'] as String?;
    final monitorName = json['powerMonitorType'] as String?;
    return Esp32Module(
      id: json['id'] as String? ??
          'esp32_${DateTime.now().microsecondsSinceEpoch}',
      name: json['name'] as String? ?? 'ESP32',
      address: json['address'] as String?,
      accessKey: json['accessKey'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      position: Esp32ModulePosition.values.firstWhere(
        (item) => item.name == positionName,
        orElse: () => Esp32ModulePosition.unspecified,
      ),
      customPositionLabel: json['customPositionLabel'] as String?,
      capabilities: Set<Esp32Capability>.unmodifiable(parsedCapabilities),
      wheelCircumferenceMm:
          (json['wheelCircumferenceMm'] as num?)?.toDouble() ?? 2100,
      hallMagnets: (json['hallMagnets'] as num?)?.toInt() ?? 1,
      minimumTirePressurePsi:
          (json['minimumTirePressurePsi'] as num?)?.toDouble() ?? 30,
      maximumTemperatureC:
          (json['maximumTemperatureC'] as num?)?.toDouble() ?? 65,
      powerSupplyType: Esp32PowerSupplyType.values.firstWhere(
        (item) => item.name == supplyName,
        orElse: () => Esp32PowerSupplyType.auto,
      ),
      batteryChemistry: Esp32BatteryChemistry.values.firstWhere(
        (item) => item.name == chemistryName,
        orElse: () => Esp32BatteryChemistry.none,
      ),
      powerMonitorType: Esp32PowerMonitorType.values.firstWhere(
        (item) => item.name == monitorName,
        orElse: () => Esp32PowerMonitorType.automatic,
      ),
      batteryNominalVoltageV:
          (json['batteryNominalVoltageV'] as num?)?.toDouble() ?? 12,
      batteryCapacityAh:
          (json['batteryCapacityAh'] as num?)?.toDouble() ?? 7,
      lowBatteryPercent:
          ((json['lowBatteryPercent'] as num?)?.toInt() ?? 25).clamp(1, 99).toInt(),
      criticalBatteryPercent:
          ((json['criticalBatteryPercent'] as num?)?.toInt() ?? 10).clamp(1, 99).toInt(),
      monitorSolarInput: json['monitorSolarInput'] as bool? ?? false,
      telemetryIntervalMs:
          (json['telemetryIntervalMs'] as num?)?.toInt() ?? 1000,
      protocolVersion: (json['protocolVersion'] as num?)?.toInt() ?? 1,
    );
  }

  factory Esp32Module.fromLegacyCameraEndpoint(CameraEndpoint endpoint) {
    final capabilities = <Esp32Capability>{Esp32Capability.battery};
    if (endpoint.esp32CameraEnabled) capabilities.add(Esp32Capability.camera);
    if (endpoint.temperatureSensorEnabled) {
      capabilities.add(Esp32Capability.temperature);
    }
    if (endpoint.hallSensorEnabled) capabilities.add(Esp32Capability.hallSpeed);
    if (endpoint.tirePressureEnabled) {
      capabilities.add(Esp32Capability.tirePressure);
    }
    return Esp32Module(
      id: endpoint.id,
      name: endpoint.name,
      address: endpoint.address,
      accessKey: endpoint.accessKey,
      enabled: endpoint.enabled,
      capabilities: Set<Esp32Capability>.unmodifiable(capabilities),
      wheelCircumferenceMm: endpoint.wheelCircumferenceMm,
      hallMagnets: endpoint.hallMagnets,
      minimumTirePressurePsi: endpoint.minimumTirePressurePsi,
      maximumTemperatureC: endpoint.maximumTemperatureC,
      telemetryIntervalMs: endpoint.telemetryIntervalMs,
    );
  }
}
