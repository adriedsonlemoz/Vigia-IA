enum RouteExplorerCategory {
  fuel,
  restaurant,
  stop,
  workshop,
  health,
  water,
  camping,
  viewpoint,
  waterfall,
  market,
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
      case RouteExplorerCategory.camping:
        return 'Camping';
      case RouteExplorerCategory.viewpoint:
        return 'Mirantes';
      case RouteExplorerCategory.waterfall:
        return 'Cachoeiras';
      case RouteExplorerCategory.market:
        return 'Mercados';
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
    this.address,
    this.openingHours,
    this.phone,
    this.website,
    this.operatorName,
    this.amenities = const <String>[],
  });

  final String id;
  final RouteExplorerCategory category;
  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final String source;
  final String? address;
  final String? openingHours;
  final String? phone;
  final String? website;
  final String? operatorName;
  final List<String> amenities;

  bool get hasExtraDetails =>
      _hasText(address) ||
      _hasText(openingHours) ||
      _hasText(phone) ||
      _hasText(website) ||
      _hasText(operatorName) ||
      amenities.isNotEmpty;

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
      address: address,
      openingHours: openingHours,
      phone: phone,
      website: website,
      operatorName: operatorName,
      amenities: amenities,
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
        if (_hasText(address)) 'address': address,
        if (_hasText(openingHours)) 'openingHours': openingHours,
        if (_hasText(phone)) 'phone': phone,
        if (_hasText(website)) 'website': website,
        if (_hasText(operatorName)) 'operatorName': operatorName,
        if (amenities.isNotEmpty) 'amenities': amenities,
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
      address: _nullableText(json['address']),
      openingHours: _nullableText(json['openingHours']),
      phone: _nullableText(json['phone']),
      website: _nullableText(json['website']),
      operatorName: _nullableText(json['operatorName']),
      amenities: ((json['amenities'] as List?) ?? const <Object>[])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
    );
  }

  static bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

class RouteExplorerSettings {
  static const int currentPoiCatalogVersion = 2;
  static const Set<RouteExplorerCategory> defaultCategories =
      <RouteExplorerCategory>{
    RouteExplorerCategory.fuel,
    RouteExplorerCategory.restaurant,
    RouteExplorerCategory.stop,
    RouteExplorerCategory.workshop,
    RouteExplorerCategory.health,
    RouteExplorerCategory.water,
    RouteExplorerCategory.camping,
    RouteExplorerCategory.viewpoint,
    RouteExplorerCategory.waterfall,
    RouteExplorerCategory.market,
  };

  const RouteExplorerSettings({
    this.radiusKm = 20,
    this.categories = defaultCategories,
    this.alertsEnabled = true,
    this.voiceEnabled = true,
    this.notificationEnabled = true,
    this.searchAheadWhenMoving = true,
    this.alertDistanceMeters = 5000,
    this.poiCatalogVersion = currentPoiCatalogVersion,
  });

  final int radiusKm;
  final Set<RouteExplorerCategory> categories;
  final bool alertsEnabled;
  final bool voiceEnabled;
  final bool notificationEnabled;
  final bool searchAheadWhenMoving;
  final int alertDistanceMeters;
  final int poiCatalogVersion;

  RouteExplorerSettings copyWith({
    int? radiusKm,
    Set<RouteExplorerCategory>? categories,
    bool? alertsEnabled,
    bool? voiceEnabled,
    bool? notificationEnabled,
    bool? searchAheadWhenMoving,
    int? alertDistanceMeters,
    int? poiCatalogVersion,
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
      poiCatalogVersion: poiCatalogVersion ?? this.poiCatalogVersion,
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
        'poiCatalogVersion': poiCatalogVersion,
      };

  factory RouteExplorerSettings.fromJson(Map<String, dynamic> json) {
    final rawCategories = (json['categories'] as List?)
            ?.map((item) => RouteExplorerCategoryX.fromStorageKey(item.toString()))
            .whereType<RouteExplorerCategory>()
            .toSet() ??
        <RouteExplorerCategory>{};
    final catalogVersion = (json['poiCatalogVersion'] as num?)?.toInt() ?? 1;
    final categories = rawCategories.isEmpty
        ? <RouteExplorerCategory>{...defaultCategories}
        : <RouteExplorerCategory>{...rawCategories};
    if (catalogVersion < currentPoiCatalogVersion) {
      categories.addAll(const <RouteExplorerCategory>{
        RouteExplorerCategory.camping,
        RouteExplorerCategory.viewpoint,
        RouteExplorerCategory.waterfall,
        RouteExplorerCategory.market,
      });
    }
    return RouteExplorerSettings(
      radiusKm: (json['radiusKm'] as num?)?.toInt() ?? 20,
      categories: categories,
      alertsEnabled: json['alertsEnabled'] as bool? ?? true,
      voiceEnabled: json['voiceEnabled'] as bool? ?? true,
      notificationEnabled: json['notificationEnabled'] as bool? ?? true,
      searchAheadWhenMoving: json['searchAheadWhenMoving'] as bool? ?? true,
      alertDistanceMeters: (json['alertDistanceMeters'] as num?)?.toInt() ?? 5000,
      poiCatalogVersion: currentPoiCatalogVersion,
    );
  }
}
