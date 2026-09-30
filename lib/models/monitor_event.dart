import 'detection.dart';

enum MonitorEventType { alert, entered, exited, cameraObstructed, cameraMoved }

class MonitorEvent {
  const MonitorEvent({
    required this.id,
    required this.createdAt,
    required this.label,
    required this.displayLabel,
    required this.confidence,
    required this.source,
    required this.box,
    this.snapshotPath,
    this.clipPath,
    this.type = MonitorEventType.alert,
    this.trackId,
    this.zoneId,
    this.zoneName,
    this.cameraId,
  });

  final String id;
  final DateTime createdAt;
  final String label;
  final String displayLabel;
  final double confidence;
  final String source;
  final NormalizedBox box;
  final String? snapshotPath;
  final String? clipPath;
  final MonitorEventType type;
  final int? trackId;
  final String? zoneId;
  final String? zoneName;
  final String? cameraId;

  MonitorEvent copyWith({
    String? snapshotPath,
    String? clipPath,
  }) =>
      MonitorEvent(
        id: id,
        createdAt: createdAt,
        label: label,
        displayLabel: displayLabel,
        confidence: confidence,
        source: source,
        box: box,
        snapshotPath: snapshotPath ?? this.snapshotPath,
        clipPath: clipPath ?? this.clipPath,
        type: type,
        trackId: trackId,
        zoneId: zoneId,
        zoneName: zoneName,
        cameraId: cameraId,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'label': label,
        'displayLabel': displayLabel,
        'confidence': confidence,
        'source': source,
        'snapshotPath': snapshotPath,
        'clipPath': clipPath,
        'type': type.name,
        'trackId': trackId,
        'zoneId': zoneId,
        'zoneName': zoneName,
        'cameraId': cameraId,
        'box': <String, Object?>{
          'yMin': box.yMin,
          'xMin': box.xMin,
          'yMax': box.yMax,
          'xMax': box.xMax,
        },
      };

  factory MonitorEvent.fromJson(Map<String, dynamic> json) {
    final boxJson = (json['box'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final typeName = json['type'] as String?;
    final type = MonitorEventType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => MonitorEventType.alert,
    );
    return MonitorEvent(
      id: json['id'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      label: json['label'] as String? ?? 'unknown',
      displayLabel: json['displayLabel'] as String? ?? 'Objeto',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      source: json['source'] as String? ?? 'Desconhecida',
      snapshotPath: json['snapshotPath'] as String?,
      clipPath: json['clipPath'] as String?,
      type: type,
      trackId: (json['trackId'] as num?)?.toInt(),
      zoneId: json['zoneId'] as String?,
      zoneName: json['zoneName'] as String?,
      cameraId: json['cameraId'] as String?,
      box: NormalizedBox(
        yMin: (boxJson['yMin'] as num?)?.toDouble() ?? 0,
        xMin: (boxJson['xMin'] as num?)?.toDouble() ?? 0,
        yMax: (boxJson['yMax'] as num?)?.toDouble() ?? 1,
        xMax: (boxJson['xMax'] as num?)?.toDouble() ?? 1,
      ),
    );
  }
}
