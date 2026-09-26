import 'route_explorer_models.dart';

enum MapDestinationKind {
  city,
  town,
  village,
  community,
  pointOfInterest,
  place,
}

extension MapDestinationKindX on MapDestinationKind {
  String get label => switch (this) {
        MapDestinationKind.city => 'Cidade',
        MapDestinationKind.town => 'Cidade',
        MapDestinationKind.village => 'Vila',
        MapDestinationKind.community => 'Comunidade',
        MapDestinationKind.pointOfInterest => 'Ponto',
        MapDestinationKind.place => 'Local',
      };

  static MapDestinationKind fromOsmType(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'city' => MapDestinationKind.city,
      'town' => MapDestinationKind.town,
      'village' => MapDestinationKind.village,
      'hamlet' || 'isolated_dwelling' => MapDestinationKind.community,
      _ => MapDestinationKind.place,
    };
  }
}

class MapDestinationSearchResult {
  const MapDestinationSearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.kind,
    required this.source,
    this.poiCategory,
  });

  final String id;
  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final MapDestinationKind kind;
  final String source;
  final RouteExplorerCategory? poiCategory;

  bool get offline => source == 'offline';
  bool get storedLocally => source == 'offline' || source == 'cache';

  MapDestinationSearchResult copyWith({
    double? distanceMeters,
    String? source,
  }) {
    return MapDestinationSearchResult(
      id: id,
      title: title,
      subtitle: subtitle,
      latitude: latitude,
      longitude: longitude,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      kind: kind,
      source: source ?? this.source,
      poiCategory: poiCategory,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'latitude': latitude,
        'longitude': longitude,
        'kind': kind.name,
      };

  factory MapDestinationSearchResult.fromJson(Map<String, dynamic> json) {
    return MapDestinationSearchResult(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Local',
      subtitle: json['subtitle'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      distanceMeters: 0,
      kind: MapDestinationKind.values.firstWhere(
        (value) => value.name == json['kind'],
        orElse: () => MapDestinationKind.place,
      ),
      source: 'cache',
    );
  }
}
