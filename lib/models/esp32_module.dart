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
        Esp32Capability.battery => 'Bateria',
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
  final int telemetryIntervalMs;
  final int protocolVersion;

  bool supports(Esp32Capability capability) => capabilities.contains(capability);

  bool get cameraEnabled => supports(Esp32Capability.camera);
  bool get temperatureSensorEnabled => supports(Esp32Capability.temperature);
  bool get hallSensorEnabled => supports(Esp32Capability.hallSpeed);
  bool get tirePressureEnabled => supports(Esp32Capability.tirePressure);

  String get positionLabel {
    final custom = customPositionLabel?.trim() ?? '';
    if (position == Esp32ModulePosition.custom && custom.isNotEmpty) {
      return custom;
    }
    return position.label;
  }

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
      // Cadastro anterior à 1.0.120 não tinha a lista de capacidades.
      // Uma lista explicitamente vazia, porém, é válida para módulos que ainda
      // não tiveram sensores instalados e não deve ser convertida em sensores
      // padrão ao reiniciar o aplicativo.
      parsedCapabilities.addAll(const <Esp32Capability>{
        Esp32Capability.temperature,
        Esp32Capability.hallSpeed,
        Esp32Capability.tirePressure,
        Esp32Capability.battery,
      });
    }
    final positionName = json['position'] as String?;
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
