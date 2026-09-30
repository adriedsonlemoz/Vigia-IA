enum CameraEndpointType { local, rtsp, remotePhone, esp32 }

class CameraEndpoint {
  const CameraEndpoint({
    required this.id,
    required this.name,
    required this.type,
    this.address,
    this.accessKey,
    this.enabled = true,
    this.countingEnabled = false,
    this.esp32CameraEnabled = false,
    this.temperatureSensorEnabled = true,
    this.hallSensorEnabled = true,
    this.tirePressureEnabled = true,
    this.wheelCircumferenceMm = 2100,
    this.hallMagnets = 1,
    this.minimumTirePressurePsi = 30,
    this.maximumTemperatureC = 65,
    this.telemetryIntervalMs = 1000,
  });

  final String id;
  final String name;
  final CameraEndpointType type;
  final String? address;
  final String? accessKey;
  final bool enabled;

  /// Reserva de arquitetura para uma futura contagem opcional por câmera.
  /// Não é usada pelo pipeline atual e permanece desativada por padrão.
  final bool countingEnabled;
  final bool esp32CameraEnabled;
  final bool temperatureSensorEnabled;
  final bool hallSensorEnabled;
  final bool tirePressureEnabled;
  final double wheelCircumferenceMm;
  final int hallMagnets;
  final double minimumTirePressurePsi;
  final double maximumTemperatureC;
  final int telemetryIntervalMs;

  CameraEndpoint copyWith({
    String? name,
    String? address,
    String? accessKey,
    bool? enabled,
    bool? countingEnabled,
    bool? esp32CameraEnabled,
    bool? temperatureSensorEnabled,
    bool? hallSensorEnabled,
    bool? tirePressureEnabled,
    double? wheelCircumferenceMm,
    int? hallMagnets,
    double? minimumTirePressurePsi,
    double? maximumTemperatureC,
    int? telemetryIntervalMs,
  }) =>
      CameraEndpoint(
        id: id,
        name: name ?? this.name,
        type: type,
        address: address ?? this.address,
        accessKey: accessKey ?? this.accessKey,
        enabled: enabled ?? this.enabled,
        countingEnabled: countingEnabled ?? this.countingEnabled,
        esp32CameraEnabled: esp32CameraEnabled ?? this.esp32CameraEnabled,
        temperatureSensorEnabled:
            temperatureSensorEnabled ?? this.temperatureSensorEnabled,
        hallSensorEnabled: hallSensorEnabled ?? this.hallSensorEnabled,
        tirePressureEnabled: tirePressureEnabled ?? this.tirePressureEnabled,
        wheelCircumferenceMm:
            wheelCircumferenceMm ?? this.wheelCircumferenceMm,
        hallMagnets: hallMagnets ?? this.hallMagnets,
        minimumTirePressurePsi:
            minimumTirePressurePsi ?? this.minimumTirePressurePsi,
        maximumTemperatureC: maximumTemperatureC ?? this.maximumTemperatureC,
        telemetryIntervalMs: telemetryIntervalMs ?? this.telemetryIntervalMs,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'type': type.name,
        'address': address,
        'accessKey': accessKey,
        'enabled': enabled,
        'countingEnabled': countingEnabled,
        'esp32CameraEnabled': esp32CameraEnabled,
        'temperatureSensorEnabled': temperatureSensorEnabled,
        'hallSensorEnabled': hallSensorEnabled,
        'tirePressureEnabled': tirePressureEnabled,
        'wheelCircumferenceMm': wheelCircumferenceMm,
        'hallMagnets': hallMagnets,
        'minimumTirePressurePsi': minimumTirePressurePsi,
        'maximumTemperatureC': maximumTemperatureC,
        'telemetryIntervalMs': telemetryIntervalMs,
      };

  Map<String, Object?> toEsp32ConfigurationJson() => <String, Object?>{
        'name': name,
        'telemetryIntervalMs': telemetryIntervalMs,
        'camera': <String, Object?>{'enabled': esp32CameraEnabled},
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

  factory CameraEndpoint.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String?;
    return CameraEndpoint(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'Câmera',
      type: CameraEndpointType.values.firstWhere(
        (item) => item.name == typeName,
        orElse: () => CameraEndpointType.remotePhone,
      ),
      address: json['address'] as String?,
      accessKey: json['accessKey'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      countingEnabled: json['countingEnabled'] as bool? ?? false,
      esp32CameraEnabled: json['esp32CameraEnabled'] as bool? ?? false,
      temperatureSensorEnabled:
          json['temperatureSensorEnabled'] as bool? ?? true,
      hallSensorEnabled: json['hallSensorEnabled'] as bool? ?? true,
      tirePressureEnabled: json['tirePressureEnabled'] as bool? ?? true,
      wheelCircumferenceMm:
          (json['wheelCircumferenceMm'] as num?)?.toDouble() ?? 2100,
      hallMagnets: (json['hallMagnets'] as num?)?.toInt() ?? 1,
      minimumTirePressurePsi:
          (json['minimumTirePressurePsi'] as num?)?.toDouble() ?? 30,
      maximumTemperatureC:
          (json['maximumTemperatureC'] as num?)?.toDouble() ?? 65,
      telemetryIntervalMs:
          (json['telemetryIntervalMs'] as num?)?.toInt() ?? 1000,
    );
  }
}
