import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../models/alert_preferences.dart';
import '../models/map_route_point.dart';
import '../models/route_explorer_models.dart';
import 'alert_delivery_service.dart';
import 'map_route_service.dart';

class RouteExplorerService extends ChangeNotifier {
  RouteExplorerService._();

  static final RouteExplorerService instance = RouteExplorerService._();

  final MapRouteService _routeState = MapRouteService.instance;
  final AlertDeliveryService _alerts = AlertDeliveryService();
  final Distance _distance = const Distance();

  File? _file;
  Future<void>? _initializing;
  bool _initialized = false;
  bool _routeListenerAttached = false;
  bool _loading = false;
  String? _error;
  String? _statusMessage;
  String _lastSource = 'none';
  RouteExplorerSettings _settings = const RouteExplorerSettings();
  List<RouteExplorerResult> _results = const <RouteExplorerResult>[];
  List<RouteExplorerResult> _offlineResults = const <RouteExplorerResult>[];
  DateTime? _resultsUpdatedAt;
  DateTime? _offlineUpdatedAt;
  final Map<String, Set<int>> _deliveredThresholds = <String, Set<int>>{};

  bool get initialized => _initialized;
  bool get loading => _loading;
  String? get error => _error;
  String? get statusMessage => _statusMessage;
  String get lastSource => _lastSource;
  RouteExplorerSettings get settings => _settings;
  List<RouteExplorerResult> get results => List<RouteExplorerResult>.unmodifiable(_results);
  List<RouteExplorerResult> get offlineResults =>
      List<RouteExplorerResult>.unmodifiable(_offlineResults);
  DateTime? get resultsUpdatedAt => _resultsUpdatedAt;
  DateTime? get offlineUpdatedAt => _offlineUpdatedAt;
  bool get hasOfflineData => _offlineResults.isNotEmpty;

  Future<void> initialize() {
    final pending = _initializing;
    if (pending != null) return pending;
    final operation = _initializeInternal();
    _initializing = operation;
    return operation.whenComplete(() => _initializing = null);
  }

  Future<void> _initializeInternal() async {
    if (_initialized) return;
    final root = await getApplicationSupportDirectory();
    _file = File(
      '${root.path}${Platform.pathSeparator}route_explorer_state.json',
    );
    await _restore();
    await _configureAlerts();
    if (!_routeListenerAttached) {
      _routeState.addListener(_handleRouteChanged);
      _routeListenerAttached = true;
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> _configureAlerts() async {
    await _alerts.initialize(
      AlertOutputs(
        voice: _settings.voiceEnabled,
        androidNotification: _settings.notificationEnabled,
        sound: false,
        vibration: false,
      ),
    );
  }

  Future<void> setRadiusKm(int value) async {
    await initialize();
    if (_settings.radiusKm == value) return;
    _settings = _settings.copyWith(radiusKm: value);
    notifyListeners();
    await _persistNow();
  }

  Future<void> toggleCategory(RouteExplorerCategory category) async {
    await initialize();
    final categories = Set<RouteExplorerCategory>.from(_settings.categories);
    if (categories.contains(category)) {
      if (categories.length == 1) return;
      categories.remove(category);
    } else {
      categories.add(category);
    }
    _settings = _settings.copyWith(categories: categories);
    notifyListeners();
    await _persistNow();
  }

  Future<void> setAlertsEnabled(bool value) async {
    await initialize();
    if (_settings.alertsEnabled == value) return;
    _settings = _settings.copyWith(alertsEnabled: value);
    notifyListeners();
    await _persistNow();
  }

  Future<void> setVoiceEnabled(bool value) async {
    await initialize();
    if (_settings.voiceEnabled == value) return;
    _settings = _settings.copyWith(voiceEnabled: value);
    await _configureAlerts();
    notifyListeners();
    await _persistNow();
  }

  Future<void> setNotificationEnabled(bool value) async {
    await initialize();
    if (_settings.notificationEnabled == value) return;
    _settings = _settings.copyWith(notificationEnabled: value);
    await _configureAlerts();
    notifyListeners();
    await _persistNow();
  }

  Future<void> setSearchAheadWhenMoving(bool value) async {
    await initialize();
    if (_settings.searchAheadWhenMoving == value) return;
    _settings = _settings.copyWith(searchAheadWhenMoving: value);
    notifyListeners();
    await _persistNow();
  }

  Future<void> setAlertDistanceMeters(int value) async {
    await initialize();
    if (_settings.alertDistanceMeters == value) return;
    _settings = _settings.copyWith(alertDistanceMeters: value);
    _deliveredThresholds.clear();
    notifyListeners();
    await _persistNow();
  }

  Future<void> clearOfflineResults() async {
    await initialize();
    _offlineResults = const <RouteExplorerResult>[];
    _offlineUpdatedAt = null;
    if (_lastSource == 'offline') {
      _results = const <RouteExplorerResult>[];
      _lastSource = 'none';
      _resultsUpdatedAt = null;
    }
    _statusMessage = 'Lista offline excluída.';
    notifyListeners();
    await _persistNow();
  }

  Future<List<RouteExplorerResult>> searchNow({
    bool requestPermission = true,
    bool saveAsOffline = false,
  }) async {
    await initialize();
    _loading = true;
    _error = null;
    _statusMessage = null;
    notifyListeners();

    try {
      await _routeState.initialize(requestPermission: requestPermission);
      await _routeState.ensureLocation(requestPermission: requestPermission);
      final current = _routeState.current;
      if (current == null) {
        throw StateError('Localização indisponível para explorar a região.');
      }

      final onlineResults = await _fetchOnline(current);
      _results = onlineResults;
      _resultsUpdatedAt = DateTime.now();
      _lastSource = 'online';
      _statusMessage = onlineResults.isEmpty
          ? 'Nenhum local compatível encontrado neste raio.'
          : 'Busca online concluída.';
      _deliveredThresholds.clear();
      if (saveAsOffline) {
        _offlineResults = onlineResults
            .map((item) => item.copyWith(source: 'offline'))
            .toList(growable: false);
        _offlineUpdatedAt = DateTime.now();
      }
      _evaluateAlerts(current);
      await _persistNow();
      return _results;
    } catch (error) {
      final current = _routeState.current;
      if (_offlineResults.isNotEmpty && current != null) {
        _results = _recalculateDistances(
          _offlineResults,
          current,
          source: 'offline',
        );
        _resultsUpdatedAt = DateTime.now();
        _lastSource = 'offline';
        _statusMessage =
            'Sem internet no momento. Usando a lista offline salva.';
        _error = null;
        _evaluateAlerts(current);
        await _persistNow();
        return _results;
      }
      _error = error.toString().replaceFirst('Exception: ', '');
      _statusMessage = null;
      return _results;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> saveCurrentResultsOffline() async {
    await initialize();
    if (_results.isEmpty) {
      await searchNow(requestPermission: true, saveAsOffline: true);
      return;
    }
    _offlineResults = _results
        .map((item) => item.copyWith(source: 'offline'))
        .toList(growable: false);
    _offlineUpdatedAt = DateTime.now();
    _statusMessage = 'Lista salva para uso offline.';
    notifyListeners();
    await _persistNow();
  }

  void _handleRouteChanged() {
    final point = _routeState.current;
    if (point == null) return;
    if (_results.isNotEmpty) {
      _results = _recalculateDistances(
        _results,
        point,
        source: _lastSource == 'offline' ? 'offline' : 'online',
      );
      notifyListeners();
    } else if (_offlineResults.isNotEmpty) {
      _results = _recalculateDistances(
        _offlineResults,
        point,
        source: 'offline',
      );
      notifyListeners();
    }
    _evaluateAlerts(point);
  }

  Future<List<RouteExplorerResult>> _fetchOnline(MapRoutePoint current) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final query = _buildOverpassQuery(
        latitude: current.latitude,
        longitude: current.longitude,
        radiusMeters: _settings.radiusKm * 1000,
        categories: _settings.categories,
      );
      final request = await client.postUrl(
        Uri.parse('https://overpass-api.de/api/interpreter'),
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'VigiaIA/1.0.120');
      request.headers.contentType = ContentType.parse(
        'application/x-www-form-urlencoded; charset=utf-8',
      );
      request.write('data=${Uri.encodeQueryComponent(query)}');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Falha ao consultar locais úteis (${response.statusCode}).',
        );
      }
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final rawElements = decoded['elements'] as List? ?? const <Object>[];
      final origin = LatLng(current.latitude, current.longitude);
      final results = <RouteExplorerResult>[];
      final seen = <String>{};
      for (final raw in rawElements) {
        if (raw is! Map<String, dynamic>) continue;
        final coordinates = _readCoordinates(raw);
        if (coordinates == null) continue;
        final tags = (raw['tags'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ) ??
            const <String, String>{};
        final category = _resolveCategory(tags);
        if (category == null || !_settings.categories.contains(category)) {
          continue;
        }
        if (_settings.searchAheadWhenMoving && !_isAheadOrNearby(current, coordinates)) {
          continue;
        }
        final distanceMeters = _distance.as(
          LengthUnit.Meter,
          origin,
          coordinates,
        );
        final title = _resolveTitle(category, tags);
        final uniqueKey =
            '${category.name}:${title.toLowerCase()}:${coordinates.latitude.toStringAsFixed(4)}:${coordinates.longitude.toStringAsFixed(4)}';
        if (!seen.add(uniqueKey)) continue;
        results.add(
          RouteExplorerResult(
            id:
                '${raw['type'] ?? 'item'}-${raw['id'] ?? title.hashCode}-${category.name}',
            category: category,
            title: title,
            subtitle: _resolveSubtitle(category, tags),
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            distanceMeters: distanceMeters,
          ),
        );
      }
      results.sort(
        (a, b) => a.distanceMeters.compareTo(b.distanceMeters),
      );
      return results.take(12).toList(growable: false);
    } finally {
      client.close(force: true);
    }
  }

  List<RouteExplorerResult> _recalculateDistances(
    List<RouteExplorerResult> itemsSource,
    MapRoutePoint current, {
    required String source,
  }) {
    final origin = LatLng(current.latitude, current.longitude);
    final items = itemsSource
        .map(
          (item) => item.copyWith(
            distanceMeters: _distance.as(
              LengthUnit.Meter,
              origin,
              LatLng(item.latitude, item.longitude),
            ),
            source: source,
          ),
        )
        .toList(growable: false)
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return items.take(12).toList(growable: false);
  }

  LatLng? _readCoordinates(Map<String, dynamic> raw) {
    final lat = (raw['lat'] as num?)?.toDouble();
    final lon = (raw['lon'] as num?)?.toDouble();
    if (lat != null && lon != null) return LatLng(lat, lon);
    final center = raw['center'];
    if (center is Map) {
      final centerLat = (center['lat'] as num?)?.toDouble();
      final centerLon = (center['lon'] as num?)?.toDouble();
      if (centerLat != null && centerLon != null) {
        return LatLng(centerLat, centerLon);
      }
    }
    return null;
  }

  bool _isAheadOrNearby(MapRoutePoint current, LatLng target) {
    final distanceMeters = _distance.as(
      LengthUnit.Meter,
      LatLng(current.latitude, current.longitude),
      target,
    );
    if (distanceMeters <= 1500) return true;
    final heading = current.headingDegrees;
    if (!_settings.searchAheadWhenMoving || heading == null) return true;
    if (current.speedKilometersPerHour < 8) return true;
    final bearing = _bearingDegrees(
      current.latitude,
      current.longitude,
      target.latitude,
      target.longitude,
    );
    final delta = ((bearing - heading + 540) % 360) - 180;
    return delta.abs() <= 80;
  }

  double _bearingDegrees(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final deltaLambda = (lon2 - lon1) * math.pi / 180;
    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);
    final theta = math.atan2(y, x) * 180 / math.pi;
    return (theta + 360) % 360;
  }

  String _buildOverpassQuery({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required Set<RouteExplorerCategory> categories,
  }) {
    final buffer = StringBuffer('[out:json][timeout:18];(');
    for (final category in categories) {
      for (final clause in _clausesFor(category)) {
        for (final type in const <String>['node', 'way', 'relation']) {
          buffer.writeln(
            '$type(around:$radiusMeters,$latitude,$longitude)$clause;',
          );
        }
      }
    }
    buffer.write(');out center 64;');
    return buffer.toString();
  }

  List<String> _clausesFor(RouteExplorerCategory category) {
    switch (category) {
      case RouteExplorerCategory.fuel:
        return const <String>['["amenity"="fuel"]'];
      case RouteExplorerCategory.restaurant:
        return const <String>[
          '["amenity"="restaurant"]',
          '["amenity"="fast_food"]',
          '["amenity"="cafe"]',
        ];
      case RouteExplorerCategory.stop:
        return const <String>[
          '["amenity"="parking"]',
          '["amenity"="shelter"]',
          '["amenity"="bus_station"]',
          '["tourism"="camp_site"]',
        ];
      case RouteExplorerCategory.workshop:
        return const <String>[
          '["shop"="car_repair"]',
          '["shop"="bicycle"]',
          '["amenity"="bicycle_repair_station"]',
        ];
      case RouteExplorerCategory.health:
        return const <String>[
          '["amenity"="pharmacy"]',
          '["amenity"="hospital"]',
          '["amenity"="clinic"]',
          '["amenity"="doctors"]',
        ];
      case RouteExplorerCategory.water:
        return const <String>[
          '["amenity"="drinking_water"]',
          '["amenity"="toilets"]',
          '["amenity"="shower"]',
        ];
      case RouteExplorerCategory.riverBridge:
        return const <String>[
          '["waterway"="river"]',
          '["waterway"="stream"]',
          '["bridge"]',
          '["man_made"="bridge"]',
        ];
    }
  }

  RouteExplorerCategory? _resolveCategory(
    Map<String, String> tags,
  ) {
    final amenity = tags['amenity'];
    final tourism = tags['tourism'];
    final shop = tags['shop'];
    final waterway = tags['waterway'];
    final manMade = tags['man_made'];
    final bridge = tags['bridge'];
    if (amenity == 'fuel') return RouteExplorerCategory.fuel;
    if (amenity == 'restaurant' || amenity == 'fast_food' || amenity == 'cafe') {
      return RouteExplorerCategory.restaurant;
    }
    if (amenity == 'parking' ||
        amenity == 'shelter' ||
        amenity == 'bus_station' ||
        tourism == 'camp_site') {
      return RouteExplorerCategory.stop;
    }
    if (shop == 'car_repair' ||
        shop == 'bicycle' ||
        amenity == 'bicycle_repair_station') {
      return RouteExplorerCategory.workshop;
    }
    if (amenity == 'pharmacy' ||
        amenity == 'hospital' ||
        amenity == 'clinic' ||
        amenity == 'doctors') {
      return RouteExplorerCategory.health;
    }
    if (amenity == 'drinking_water' || amenity == 'toilets' || amenity == 'shower') {
      return RouteExplorerCategory.water;
    }
    if (waterway == 'river' ||
        waterway == 'stream' ||
        manMade == 'bridge' ||
        (bridge != null && bridge.isNotEmpty)) {
      return RouteExplorerCategory.riverBridge;
    }
    return null;
  }

  String _resolveTitle(
    RouteExplorerCategory category,
    Map<String, String> tags,
  ) {
    final name = tags['name'];
    if (name != null && name.trim().isNotEmpty) return name.trim();
    switch (category) {
      case RouteExplorerCategory.fuel:
        return 'Posto próximo';
      case RouteExplorerCategory.restaurant:
        return 'Restaurante próximo';
      case RouteExplorerCategory.stop:
        return 'Parada próxima';
      case RouteExplorerCategory.workshop:
        return 'Oficina próxima';
      case RouteExplorerCategory.health:
        return 'Ponto de saúde';
      case RouteExplorerCategory.water:
        return 'Água/banheiro';
      case RouteExplorerCategory.riverBridge:
        return 'Rio ou ponte';
    }
  }

  String _resolveSubtitle(
    RouteExplorerCategory category,
    Map<String, String> tags,
  ) {
    final details = <String>[];
    final ref = tags['ref'];
    final street = tags['addr:street'];
    final brand = tags['brand'];
    final description = tags['description'];
    switch (category) {
      case RouteExplorerCategory.fuel:
        details.add(brand?.trim().isNotEmpty == true ? brand!.trim() : 'Combustível');
        break;
      case RouteExplorerCategory.restaurant:
        details.add('Alimentação');
        break;
      case RouteExplorerCategory.stop:
        details.add('Parada');
        break;
      case RouteExplorerCategory.workshop:
        details.add('Suporte mecânico');
        break;
      case RouteExplorerCategory.health:
        details.add('Atendimento');
        break;
      case RouteExplorerCategory.water:
        details.add('Água ou banheiro');
        break;
      case RouteExplorerCategory.riverBridge:
        details.add('Referência no caminho');
        break;
    }
    if (ref != null && ref.trim().isNotEmpty) details.add(ref.trim());
    if (street != null && street.trim().isNotEmpty) details.add(street.trim());
    if (description != null && description.trim().isNotEmpty) {
      details.add(description.trim());
    }
    return details.join(' · ');
  }

  void _evaluateAlerts(MapRoutePoint current) {
    if (!_settings.alertsEnabled) return;
    final activeResults = _results.isNotEmpty ? _results : _offlineResults;
    if (activeResults.isEmpty) return;

    for (final item in activeResults) {
      final distanceMeters = _distance.as(
        LengthUnit.Meter,
        LatLng(current.latitude, current.longitude),
        LatLng(item.latitude, item.longitude),
      );
      if (_settings.searchAheadWhenMoving &&
          !_isAheadOrNearby(current, LatLng(item.latitude, item.longitude))) {
        continue;
      }
      final thresholds = <int>{_settings.alertDistanceMeters, 1000}.toList()
        ..sort((a, b) => b.compareTo(a));
      final delivered = _deliveredThresholds.putIfAbsent(item.id, () => <int>{});
      for (final threshold in thresholds) {
        if (distanceMeters <= threshold && !delivered.contains(threshold)) {
          delivered.add(threshold);
          unawaited(
            _alerts.deliver(
              _buildAlertMessage(item, distanceMeters),
              title: 'Mapa e percurso',
            ),
          );
          break;
        }
      }
    }
  }

  String _buildAlertMessage(RouteExplorerResult item, double distanceMeters) {
    final prefix = switch (item.category) {
      RouteExplorerCategory.fuel => 'Próximo posto',
      RouteExplorerCategory.restaurant => 'Próximo restaurante',
      RouteExplorerCategory.stop => 'Próxima parada',
      RouteExplorerCategory.workshop => 'Próxima oficina',
      RouteExplorerCategory.health => 'Próximo ponto de saúde',
      RouteExplorerCategory.water => 'Próximo ponto de água ou banheiro',
      RouteExplorerCategory.riverBridge => 'Próxima referência',
    };
    return '$prefix em ${formatDistance(distanceMeters)}: ${item.title}.';
  }

  String formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(meters < 10000 ? 1 : 0)} km';
  }

  Future<void> _restore() async {
    final file = _file;
    if (file == null || !await file.exists()) return;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return;
      final settingsJson = decoded['settings'];
      if (settingsJson is Map<String, dynamic>) {
        _settings = RouteExplorerSettings.fromJson(settingsJson);
      } else if (settingsJson is Map) {
        _settings = RouteExplorerSettings.fromJson(
          settingsJson.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        );
      }
      _results = ((decoded['results'] as List?) ?? const <Object>[])
          .whereType<Map>()
          .map(
            (item) => RouteExplorerResult.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false);
      _offlineResults = ((decoded['offlineResults'] as List?) ?? const <Object>[])
          .whereType<Map>()
          .map(
            (item) => RouteExplorerResult.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false);
      final resultsUpdatedAt = decoded['resultsUpdatedAt'] as String?;
      final offlineUpdatedAt = decoded['offlineUpdatedAt'] as String?;
      _resultsUpdatedAt = resultsUpdatedAt == null
          ? null
          : DateTime.tryParse(resultsUpdatedAt);
      _offlineUpdatedAt = offlineUpdatedAt == null
          ? null
          : DateTime.tryParse(offlineUpdatedAt);
      _lastSource = decoded['lastSource'] as String? ?? 'none';
      _statusMessage = decoded['statusMessage'] as String?;
    } catch (_) {
      // Ignora restauracao corrompida.
    }
  }

  Future<void> _persistNow() async {
    final file = _file;
    if (file == null) return;
    final temporary = File('${file.path}.tmp');
    final payload = <String, Object?>{
      'settings': _settings.toJson(),
      'results': _results.map((item) => item.toJson()).toList(growable: false),
      'offlineResults':
          _offlineResults.map((item) => item.toJson()).toList(growable: false),
      'resultsUpdatedAt': _resultsUpdatedAt?.toIso8601String(),
      'offlineUpdatedAt': _offlineUpdatedAt?.toIso8601String(),
      'lastSource': _lastSource,
      'statusMessage': _statusMessage,
    };
    await temporary.writeAsString(jsonEncode(payload), flush: true);
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }
}
