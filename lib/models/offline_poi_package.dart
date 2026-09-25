import 'dart:math' as math;

import 'route_explorer_models.dart';

class OfflinePoiPackage {
  const OfflinePoiPackage({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.west,
    required this.south,
    required this.east,
    required this.north,
    required this.originLatitude,
    required this.originLongitude,
    required this.searchRadiusKm,
    required this.items,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double west;
  final double south;
  final double east;
  final double north;
  final double originLatitude;
  final double originLongitude;
  final int searchRadiusKm;
  final List<RouteExplorerResult> items;

  int get itemCount => items.length;

  bool contains({
    required double latitude,
    required double longitude,
  }) =>
      latitude >= south &&
      latitude <= north &&
      longitude >= west &&
      longitude <= east;

  OfflinePoiPackage copyWith({
    String? name,
    DateTime? updatedAt,
    List<RouteExplorerResult>? items,
  }) {
    return OfflinePoiPackage(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      west: west,
      south: south,
      east: east,
      north: north,
      originLatitude: originLatitude,
      originLongitude: originLongitude,
      searchRadiusKm: searchRadiusKm,
      items: items ?? this.items,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'west': west,
        'south': south,
        'east': east,
        'north': north,
        'originLatitude': originLatitude,
        'originLongitude': originLongitude,
        'searchRadiusKm': searchRadiusKm,
        'items': items.map((item) => item.toJson()).toList(growable: false),
      };

  factory OfflinePoiPackage.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const <Object>[];
    return OfflinePoiPackage(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Região offline',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      west: (json['west'] as num?)?.toDouble() ?? -180,
      south: (json['south'] as num?)?.toDouble() ?? -90,
      east: (json['east'] as num?)?.toDouble() ?? 180,
      north: (json['north'] as num?)?.toDouble() ?? 90,
      originLatitude: (json['originLatitude'] as num?)?.toDouble() ?? 0,
      originLongitude: (json['originLongitude'] as num?)?.toDouble() ?? 0,
      searchRadiusKm: (json['searchRadiusKm'] as num?)?.toInt() ?? 20,
      items: rawItems
          .whereType<Map>()
          .map(
            (item) => RouteExplorerResult.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false),
    );
  }

  factory OfflinePoiPackage.fromResults({
    required String id,
    required String name,
    required DateTime now,
    required double originLatitude,
    required double originLongitude,
    required int searchRadiusKm,
    required List<RouteExplorerResult> items,
  }) {
    final latDelta = searchRadiusKm / 111.32;
    final latitudeRadians = originLatitude * math.pi / 180;
    final longitudeScale = math.cos(latitudeRadians).abs().clamp(0.15, 1.0);
    final lonDelta = searchRadiusKm / (111.32 * longitudeScale);
    return OfflinePoiPackage(
      id: id,
      name: name,
      createdAt: now,
      updatedAt: now,
      west: (originLongitude - lonDelta).clamp(-180.0, 180.0).toDouble(),
      south: (originLatitude - latDelta).clamp(-90.0, 90.0).toDouble(),
      east: (originLongitude + lonDelta).clamp(-180.0, 180.0).toDouble(),
      north: (originLatitude + latDelta).clamp(-90.0, 90.0).toDouble(),
      originLatitude: originLatitude,
      originLongitude: originLongitude,
      searchRadiusKm: searchRadiusKm,
      items: items,
    );
  }
}
