class MonitoringZone {
  const MonitoringZone({
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
  });

  const MonitoringZone.fullFrame()
      : xMin = 0,
        yMin = 0,
        xMax = 1,
        yMax = 1;

  final double xMin;
  final double yMin;
  final double xMax;
  final double yMax;

  double get width => xMax - xMin;
  double get height => yMax - yMin;
  double get area => width * height;
  bool get isFullFrame =>
      xMin <= 0 && yMin <= 0 && xMax >= 1 && yMax >= 1;

  MonitoringZone normalized({double minimumSize = 0.08}) {
    var left = xMin.clamp(0.0, 1.0).toDouble();
    var top = yMin.clamp(0.0, 1.0).toDouble();
    var right = xMax.clamp(0.0, 1.0).toDouble();
    var bottom = yMax.clamp(0.0, 1.0).toDouble();

    if (right < left) {
      final temp = right;
      right = left;
      left = temp;
    }
    if (bottom < top) {
      final temp = bottom;
      bottom = top;
      top = temp;
    }

    if (right - left < minimumSize) {
      final center = (left + right) / 2;
      left = (center - minimumSize / 2).clamp(0.0, 1.0).toDouble();
      right = (left + minimumSize).clamp(0.0, 1.0).toDouble();
      left = (right - minimumSize).clamp(0.0, 1.0).toDouble();
    }
    if (bottom - top < minimumSize) {
      final center = (top + bottom) / 2;
      top = (center - minimumSize / 2).clamp(0.0, 1.0).toDouble();
      bottom = (top + minimumSize).clamp(0.0, 1.0).toDouble();
      top = (bottom - minimumSize).clamp(0.0, 1.0).toDouble();
    }

    return MonitoringZone(
      xMin: left,
      yMin: top,
      xMax: right,
      yMax: bottom,
    );
  }

  bool contains(double x, double y) {
    final n = normalized(minimumSize: 0);
    return x >= n.xMin && x <= n.xMax && y >= n.yMin && y <= n.yMax;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'xMin': xMin,
        'yMin': yMin,
        'xMax': xMax,
        'yMax': yMax,
      };

  factory MonitoringZone.fromJson(Map<String, dynamic> json) => MonitoringZone(
        xMin: (json['xMin'] as num?)?.toDouble() ?? 0,
        yMin: (json['yMin'] as num?)?.toDouble() ?? 0,
        xMax: (json['xMax'] as num?)?.toDouble() ?? 1,
        yMax: (json['yMax'] as num?)?.toDouble() ?? 1,
      ).normalized();

  @override
  bool operator ==(Object other) =>
      other is MonitoringZone &&
      other.xMin == xMin &&
      other.yMin == yMin &&
      other.xMax == xMax &&
      other.yMax == yMax;

  @override
  int get hashCode => Object.hash(xMin, yMin, xMax, yMax);
}

class MonitoringZoneProfile {
  const MonitoringZoneProfile({
    required this.id,
    required this.name,
    required this.zone,
    this.enabled = true,
  });

  const MonitoringZoneProfile.primary()
      : id = 'principal',
        name = 'Área principal',
        zone = const MonitoringZone.fullFrame(),
        enabled = false;

  final String id;
  final String name;
  final MonitoringZone zone;
  final bool enabled;

  MonitoringZoneProfile copyWith({
    String? id,
    String? name,
    MonitoringZone? zone,
    bool? enabled,
  }) =>
      MonitoringZoneProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        zone: zone ?? this.zone,
        enabled: enabled ?? this.enabled,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'enabled': enabled,
        'zone': zone.toJson(),
      };

  factory MonitoringZoneProfile.fromJson(Map<String, dynamic> json) {
    final rawZone = (json['zone'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return MonitoringZoneProfile(
      id: json['id'] as String? ?? 'zona',
      name: json['name'] as String? ?? 'Área',
      enabled: json['enabled'] as bool? ?? true,
      zone: MonitoringZone.fromJson(rawZone),
    );
  }
}
