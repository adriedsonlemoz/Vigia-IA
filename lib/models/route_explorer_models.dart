enum RouteExplorerCategory {
  fuel,
  restaurant,
  stop,
  workshop,
  health,
  water,
  riverBridge,
}

extension RouteExplorerCategoryX on RouteExplorerCategory {
  String get label {
    switch (this) {
      case RouteExplorerCategory.fuel:
        return 'Postos';
      case RouteExplorerCategory.restaurant:
        return 'Restaurantes';
      case RouteExplorerCategory.stop:
        return 'Paradas';
      case RouteExplorerCategory.workshop:
        return 'Oficinas';
      case RouteExplorerCategory.health:
        return 'Saúde';
      case RouteExplorerCategory.water:
        return 'Água/banheiro';
      case RouteExplorerCategory.riverBridge:
        return 'Rios e pontes';
    }
  }

  String get storageKey => name;

  static RouteExplorerCategory? fromStorageKey(String key) {
    for (final value in RouteExplorerCategory.values) {
      if (value.name == key) return value;
    }
    return null;
  }
}

class RouteExplorerResult {
  const RouteExplorerResult({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    this.source = 'online',
  });

  final String id;
  final RouteExplorerCategory category;
  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final String source;

  RouteExplorerResult copyWith({
    double? distanceMeters,
    String? source,
  }) {
    return RouteExplorerResult(
      id: id,
      category: category,
      title: title,
      subtitle: subtitle,
      latitude: latitude,
      longitude: longitude,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      source: source ?? this.source,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'category': category.storageKey,
        'title': title,
        'subtitle': subtitle,
        'latitude': latitude,
        'longitude': longitude,
        'distanceMeters': distanceMeters,
        'source': source,
      };

  factory RouteExplorerResult.fromJson(Map<String, dynamic> json) {
    final category = RouteExplorerCategoryX.fromStorageKey(
          json['category'] as String? ?? '',
        ) ??
        RouteExplorerCategory.stop;
    return RouteExplorerResult(
      id: json['id'] as String? ?? '',
      category: category,
      title: json['title'] as String? ?? 'Ponto de interesse',
      subtitle: json['subtitle'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
      source: json['source'] as String? ?? 'online',
    );
  }
}

class RouteExplorerSettings {
  const RouteExplorerSettings({
    this.radiusKm = 20,
    this.categories = const <RouteExplorerCategory>{
      RouteExplorerCategory.fuel,
      RouteExplorerCategory.restaurant,
      RouteExplorerCategory.stop,
      RouteExplorerCategory.water,
    },
    this.alertsEnabled = true,
    this.voiceEnabled = true,
    this.notificationEnabled = true,
    this.searchAheadWhenMoving = true,
    this.alertDistanceMeters = 5000,
  });

  final int radiusKm;
  final Set<RouteExplorerCategory> categories;
  final bool alertsEnabled;
  final bool voiceEnabled;
  final bool notificationEnabled;
  final bool searchAheadWhenMoving;
  final int alertDistanceMeters;

  RouteExplorerSettings copyWith({
    int? radiusKm,
    Set<RouteExplorerCategory>? categories,
    bool? alertsEnabled,
    bool? voiceEnabled,
    bool? notificationEnabled,
    bool? searchAheadWhenMoving,
    int? alertDistanceMeters,
  }) {
    return RouteExplorerSettings(
      radiusKm: radiusKm ?? this.radiusKm,
      categories: categories ?? this.categories,
      alertsEnabled: alertsEnabled ?? this.alertsEnabled,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      searchAheadWhenMoving:
          searchAheadWhenMoving ?? this.searchAheadWhenMoving,
      alertDistanceMeters: alertDistanceMeters ?? this.alertDistanceMeters,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'radiusKm': radiusKm,
        'categories': categories.map((item) => item.storageKey).toList(),
        'alertsEnabled': alertsEnabled,
        'voiceEnabled': voiceEnabled,
        'notificationEnabled': notificationEnabled,
        'searchAheadWhenMoving': searchAheadWhenMoving,
        'alertDistanceMeters': alertDistanceMeters,
      };

  factory RouteExplorerSettings.fromJson(Map<String, dynamic> json) {
    final rawCategories = (json['categories'] as List?)
            ?.map((item) => RouteExplorerCategoryX.fromStorageKey(item.toString()))
            .whereType<RouteExplorerCategory>()
            .toSet() ??
        const <RouteExplorerCategory>{};
    return RouteExplorerSettings(
      radiusKm: (json['radiusKm'] as num?)?.toInt() ?? 20,
      categories: rawCategories.isEmpty
          ? const <RouteExplorerCategory>{
              RouteExplorerCategory.fuel,
              RouteExplorerCategory.restaurant,
              RouteExplorerCategory.stop,
              RouteExplorerCategory.water,
            }
          : rawCategories,
      alertsEnabled: json['alertsEnabled'] as bool? ?? true,
      voiceEnabled: json['voiceEnabled'] as bool? ?? true,
      notificationEnabled: json['notificationEnabled'] as bool? ?? true,
      searchAheadWhenMoving: json['searchAheadWhenMoving'] as bool? ?? true,
      alertDistanceMeters: (json['alertDistanceMeters'] as num?)?.toInt() ?? 5000,
    );
  }
}
