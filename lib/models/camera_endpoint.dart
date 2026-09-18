enum CameraEndpointType { local, rtsp, remotePhone }

class CameraEndpoint {
  const CameraEndpoint({
    required this.id,
    required this.name,
    required this.type,
    this.address,
    this.accessKey,
    this.enabled = true,
    this.countingEnabled = false,
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

  CameraEndpoint copyWith({
    String? name,
    String? address,
    String? accessKey,
    bool? enabled,
    bool? countingEnabled,
  }) =>
      CameraEndpoint(
        id: id,
        name: name ?? this.name,
        type: type,
        address: address ?? this.address,
        accessKey: accessKey ?? this.accessKey,
        enabled: enabled ?? this.enabled,
        countingEnabled: countingEnabled ?? this.countingEnabled,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'type': type.name,
        'address': address,
        'accessKey': accessKey,
        'enabled': enabled,
        'countingEnabled': countingEnabled,
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
    );
  }
}
