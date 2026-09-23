enum OfflineMapMode { automatic, online, offline }

class OfflineMapPackage {
  const OfflineMapPackage({
    required this.id,
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.addedAt,
    this.updatedAt,
    this.sourceHost,
    this.providerId,
    this.downloadKind,
    this.west,
    this.south,
    this.east,
    this.north,
    this.minZoom,
    this.maxZoom,
    this.expiresAt,
  });

  final String id;
  final String name;
  final String path;
  final int sizeBytes;
  final DateTime addedAt;
  final DateTime? updatedAt;
  final String? sourceHost;
  final String? providerId;
  final String? downloadKind;
  final double? west;
  final double? south;
  final double? east;
  final double? north;
  final int? minZoom;
  final int? maxZoom;
  final DateTime? expiresAt;

  bool get hasBounds =>
      west != null && south != null && east != null && north != null;

  bool contains({required double latitude, required double longitude}) {
    if (!hasBounds) return true;
    return latitude >= south! &&
        latitude <= north! &&
        longitude >= west! &&
        longitude <= east!;
  }

  bool get refreshRecommended =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  OfflineMapPackage copyWith({
    String? name,
    String? path,
    int? sizeBytes,
    DateTime? updatedAt,
    String? sourceHost,
    String? providerId,
    String? downloadKind,
    double? west,
    double? south,
    double? east,
    double? north,
    int? minZoom,
    int? maxZoom,
    DateTime? expiresAt,
  }) {
    return OfflineMapPackage(
      id: id,
      name: name ?? this.name,
      path: path ?? this.path,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      addedAt: addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sourceHost: sourceHost ?? this.sourceHost,
      providerId: providerId ?? this.providerId,
      downloadKind: downloadKind ?? this.downloadKind,
      west: west ?? this.west,
      south: south ?? this.south,
      east: east ?? this.east,
      north: north ?? this.north,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'path': path,
        'sizeBytes': sizeBytes,
        'addedAt': addedAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'sourceHost': sourceHost,
        'providerId': providerId,
        'downloadKind': downloadKind,
        'west': west,
        'south': south,
        'east': east,
        'north': north,
        'minZoom': minZoom,
        'maxZoom': maxZoom,
        'expiresAt': expiresAt?.toIso8601String(),
      };

  factory OfflineMapPackage.fromJson(Map<String, dynamic> json) {
    return OfflineMapPackage(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Mapa offline',
      path: json['path'] as String? ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      sourceHost: json['sourceHost'] as String?,
      providerId: json['providerId'] as String?,
      downloadKind: json['downloadKind'] as String?,
      west: (json['west'] as num?)?.toDouble(),
      south: (json['south'] as num?)?.toDouble(),
      east: (json['east'] as num?)?.toDouble(),
      north: (json['north'] as num?)?.toDouble(),
      minZoom: (json['minZoom'] as num?)?.toInt(),
      maxZoom: (json['maxZoom'] as num?)?.toInt(),
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
    );
  }
}
