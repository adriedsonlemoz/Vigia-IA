enum OfflineMapMode { automatic, online, offline }

class OfflineMapPackage {
  const OfflineMapPackage({
    required this.id,
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.addedAt,
    this.sourceHost,
  });

  final String id;
  final String name;
  final String path;
  final int sizeBytes;
  final DateTime addedAt;
  final String? sourceHost;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'path': path,
        'sizeBytes': sizeBytes,
        'addedAt': addedAt.toIso8601String(),
        'sourceHost': sourceHost,
      };

  factory OfflineMapPackage.fromJson(Map<String, dynamic> json) {
    return OfflineMapPackage(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Mapa offline',
      path: json['path'] as String? ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
      sourceHost: json['sourceHost'] as String?,
    );
  }
}
