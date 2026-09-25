class MapNavigationTarget {
  const MapNavigationTarget({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.startedAt,
    this.sourceId,
  });

  final double latitude;
  final double longitude;
  final String label;
  final DateTime startedAt;
  final String? sourceId;

  Map<String, Object?> toJson() => <String, Object?>{
        'latitude': latitude,
        'longitude': longitude,
        'label': label,
        'startedAt': startedAt.toIso8601String(),
        'sourceId': sourceId,
      };

  factory MapNavigationTarget.fromJson(Map<String, dynamic> json) =>
      MapNavigationTarget(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        label: (json['label'] as String?)?.trim().isNotEmpty == true
            ? (json['label'] as String).trim()
            : 'Destino',
        startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
            DateTime.now(),
        sourceId: json['sourceId'] as String?,
      );
}
