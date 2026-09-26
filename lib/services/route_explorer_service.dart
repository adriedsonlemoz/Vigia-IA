import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../models/alert_preferences.dart';
import '../models/map_route_point.dart';
import '../models/offline_poi_package.dart';
import '../models/route_explorer_models.dart';
import 'alert_delivery_service.dart';
import 'location_tracking_service.dart';
import 'map_connectivity_service.dart';
import 'map_performance_policy.dart';
import 'map_bike_consolidation_policy.dart';
import 'map_route_service.dart';
import 'route_explorer_alert_policy.dart';
import 'route_explorer_poi_catalog.dart';

class RouteExplorerService extends ChangeNotifier {
  RouteExplorerService._();

  static const int maximumResults = 36;
  static const Duration automaticRefreshInterval = Duration(minutes: 5);
  static const double automaticRefreshDistanceMeters = 1500;
  static const double automaticRefreshHeadingChangeDegrees = 50;
  static const double automaticRefreshMinimumSpeedKmh = 2.0;

  static final RouteExplorerService instance = RouteExplorerService._();

  final MapRouteService _routeState = MapRouteService.instance;
  final AlertDeliveryService _alerts = AlertDeliveryService();
  final MapConnectivityService _connectivity = MapConnectivityService.instance;
  final RouteExplorerAlertPolicy _alertPolicy = const RouteExplorerAlertPolicy();
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
  final List<OfflinePoiPackage> _offlinePackages = <OfflinePoiPackage>[];
  String? _activeOfflinePackageId;
  DateTime? _resultsUpdatedAt;
  DateTime? _offlineUpdatedAt;
  final Map<String, Set<int>> _deliveredThresholds = <String, Set<int>>{};
  DateTime? _lastAlertDeliveredAt;
  MapRoutePoint? _lastSearchOrigin;
  DateTime? _lastAutomaticSearchAt;
  DateTime? _lastAutomaticAttemptAt;
  MapRoutePoint? _lastPoiUiOrigin;
  DateTime? _lastPoiUiRefreshAt;
  double? _lastSearchHeadingDegrees;
  DateTime? _lastHandledRoutePointAt;
  bool _automaticRefreshScheduled = false;

  bool get initialized => _initialized;
  bool get loading => _loading;
  String? get error => _error;
  String? get statusMessage => _statusMessage;
  String get lastSource => _lastSource;
  RouteExplorerSettings get settings => _settings;
  List<RouteExplorerResult> get results => List<RouteExplorerResult>.unmodifiable(_results);
  List<RouteExplorerResult> get activeResults =>
      List<RouteExplorerResult>.unmodifiable(
        _results.where((item) => _settings.categories.contains(item.category)),
      );
  List<RouteExplorerResult> get offlineResults =>
      List<RouteExplorerResult>.unmodifiable(_offlineResults);
  List<OfflinePoiPackage> get offlinePackages =>
      List<OfflinePoiPackage>.unmodifiable(_offlinePackages);
  String? get activeOfflinePackageId => _activeOfflinePackageId;
  OfflinePoiPackage? get activeOfflinePackage {
    final id = _activeOfflinePackageId;
    if (id == null) return null;
    for (final package in _offlinePackages) {
      if (package.id == id) return package;
    }
    return null;
  }
  DateTime? get resultsUpdatedAt => _resultsUpdatedAt;
  DateTime? get offlineUpdatedAt => _offlineUpdatedAt;
  bool get hasOfflineData => _offlinePackages.isNotEmpty;

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
    _lastAlertDeliveredAt = null;
    notifyListeners();
    await _persistNow();
  }

  Future<void> clearOfflineResults() async {
    await initialize();
    _offlinePackages.clear();
    _activeOfflinePackageId = null;
    _offlineResults = const <RouteExplorerResult>[];
    _offlineUpdatedAt = null;
    if (_lastSource == 'offline') {
      _results = const <RouteExplorerResult>[];
      _lastSource = 'none';
      _resultsUpdatedAt = null;
    }
    _statusMessage = 'Pacotes de pontos offline excluídos.';
    notifyListeners();
    await _persistNow();
  }

  Future<void> activateOfflinePackage(String packageId) async {
    await initialize();
    OfflinePoiPackage? selected;
    for (final package in _offlinePackages) {
      if (package.id == packageId) {
        selected = package;
        break;
      }
    }
    if (selected == null) return;
    _activeOfflinePackageId = selected.id;
    _offlineResults = selected.items;
    _offlineUpdatedAt = selected.updatedAt;
    final current = _routeState.current;
    if (current != null) {
      _results = _recalculateDistances(
        selected.items,
        current,
        source: 'offline',
      );
      _lastSource = 'offline';
      _resultsUpdatedAt = DateTime.now();
    }
    _statusMessage = 'Pacote offline “${selected.name}” ativado.';
    notifyListeners();
    await _persistNow();
  }

  Future<void> removeOfflinePackage(String packageId) async {
    await initialize();
    _offlinePackages.removeWhere((item) => item.id == packageId);
    if (_activeOfflinePackageId == packageId) {
      _activeOfflinePackageId =
          _offlinePackages.isEmpty ? null : _offlinePackages.first.id;
      _syncActiveOfflineCache();
      if (_lastSource == 'offline') {
        final current = _routeState.current;
        if (current == null || _offlineResults.isEmpty) {
          _results = const <RouteExplorerResult>[];
          _lastSource = 'none';
          _resultsUpdatedAt = null;
        } else {
          _results = _recalculateDistances(
            _offlineResults,
            current,
            source: 'offline',
          );
        }
      }
    }
    _statusMessage = 'Pacote offline removido.';
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

      if (_connectivity.isOffline && !saveAsOffline) {
        final offline = _activateOfflineForPosition(
          current,
          explicitOfflineMode: false,
        );
        if (offline.isEmpty) {
          _statusMessage = _results.isEmpty
              ? 'Sem internet e sem pacote de pontos offline para esta região.'
              : 'Sem internet. Mantendo os últimos pontos carregados.';
        }
        await _persistNow();
        return _results;
      }

      final onlineResults = await _fetchOnline(current);
      _results = onlineResults;
      _resultsUpdatedAt = DateTime.now();
      _lastSearchOrigin = current;
      _lastAutomaticSearchAt = _resultsUpdatedAt;
      _lastSearchHeadingDegrees = current.headingDegrees;
      _lastPoiUiOrigin = current;
      _lastPoiUiRefreshAt = _resultsUpdatedAt;
      _lastSource = 'online';
      _statusMessage = onlineResults.isEmpty
          ? 'Nenhum local compatível encontrado neste raio.'
          : 'Busca online concluída.';
      _pruneDeliveredAlerts(onlineResults);
      if (saveAsOffline) {
        await _saveOfflinePackageFromResults(
          onlineResults,
          current: current,
          name: _defaultPackageName(),
          notify: false,
          persist: false,
        );
      }
      _evaluateAlerts(current);
      await _persistNow();
      return _results;
    } catch (error) {
      final current = _routeState.current;
      if (current != null) {
        final offline = _activateOfflineForPosition(
          current,
          explicitOfflineMode: false,
        );
        if (offline.isNotEmpty) {
          await _persistNow();
          return offline;
        }
      }
      _error = error.toString().replaceFirst('Exception: ', '');
      _statusMessage = null;
      return _results;
    } finally {
      _loading = false;
      notifyListeners();
      _routeState.releaseLocationIfIdle();
    }
  }

  Future<List<RouteExplorerResult>> useOfflineForCurrentLocation({
    bool requestPermission = false,
    bool explicitOfflineMode = false,
  }) async {
    await initialize();
    _error = null;
    await _routeState.initialize(requestPermission: requestPermission);
    await _routeState.ensureLocation(requestPermission: requestPermission);
    final current = _routeState.current;
    if (current == null) {
      _statusMessage = 'Localização indisponível para consultar os pontos offline.';
      notifyListeners();
      return _results;
    }
    final result = _activateOfflineForPosition(
      current,
      explicitOfflineMode: explicitOfflineMode,
    );
    if (result.isEmpty) {
      _statusMessage = _results.isEmpty
          ? 'Sem pacote de pontos offline para esta região.'
          : 'Sem pacote offline nesta região. Mantendo os últimos pontos carregados.';
    }
    notifyListeners();
    await _persistNow();
    return _results;
  }

  List<RouteExplorerResult> _activateOfflineForPosition(
    MapRoutePoint current, {
    required bool explicitOfflineMode,
  }) {
    _selectBestOfflinePackage(current);
    if (_offlineResults.isEmpty) return const <RouteExplorerResult>[];
    _results = _recalculateDistances(
      _offlineResults,
      current,
      source: 'offline',
    );
    _resultsUpdatedAt = DateTime.now();
    _lastSearchOrigin = current;
    _lastAutomaticSearchAt = _resultsUpdatedAt;
    _lastSearchHeadingDegrees = current.headingDegrees;
    _lastPoiUiOrigin = current;
    _lastPoiUiRefreshAt = _resultsUpdatedAt;
    _lastSource = 'offline';
    final package = activeOfflinePackage;
    if (explicitOfflineMode) {
      _statusMessage = package == null
          ? 'Modo offline ativo. Usando pontos salvos.'
          : 'Modo offline ativo · ${package.name}.';
    } else {
      _statusMessage = package == null
          ? 'Sem internet no momento. Usando pontos offline.'
          : 'Sem internet. Usando o pacote “${package.name}”.';
    }
    _error = null;
    _evaluateAlerts(current);
    notifyListeners();
    return _results;
  }

  Future<void> saveCurrentResultsOffline({String? name}) async {
    await initialize();
    if (_results.isEmpty) {
      await searchNow(requestPermission: true);
      if (_results.isEmpty) return;
    }
    final current = _routeState.current;
    if (current == null) {
      _error = 'Localização indisponível para criar o pacote offline.';
      notifyListeners();
      return;
    }
    await _saveOfflinePackageFromResults(
      _results,
      current: current,
      name: (name == null || name.trim().isEmpty)
          ? _defaultPackageName()
          : name.trim(),
    );
  }

  Future<void> updateActiveOfflinePackage() async {
    await initialize();
    final active = activeOfflinePackage;
    if (active == null) {
      await saveCurrentResultsOffline();
      return;
    }
    await updateOfflinePackage(active.id);
  }

  Future<void> updateOfflinePackage(String packageId) async {
    await initialize();
    OfflinePoiPackage? target;
    for (final package in _offlinePackages) {
      if (package.id == packageId) {
        target = package;
        break;
      }
    }
    if (target == null || _loading) return;
    final targetPackage = target;

    _loading = true;
    _error = null;
    _statusMessage = null;
    notifyListeners();
    try {
      await _routeState.initialize(requestPermission: true);
      await _routeState.ensureLocation(requestPermission: true);
      final current = _routeState.current;
      if (current == null) {
        throw StateError('Localização indisponível para atualizar o pacote.');
      }

      // Atualização de pacote deve vir da rede. Não reutilize silenciosamente
      // o próprio cache offline, pois isso mascara uma falha de atualização.
      final onlineResults = await _fetchOnline(current);
      final now = DateTime.now();
      final fresh = OfflinePoiPackage.fromResults(
        id: targetPackage.id,
        name: targetPackage.name,
        now: now,
        originLatitude: current.latitude,
        originLongitude: current.longitude,
        searchRadiusKm: _settings.radiusKm,
        items: onlineResults
            .map((item) => item.copyWith(source: 'offline'))
            .toList(growable: false),
      );
      final updated = OfflinePoiPackage(
        id: targetPackage.id,
        name: targetPackage.name,
        createdAt: targetPackage.createdAt,
        updatedAt: now,
        west: fresh.west,
        south: fresh.south,
        east: fresh.east,
        north: fresh.north,
        originLatitude: fresh.originLatitude,
        originLongitude: fresh.originLongitude,
        searchRadiusKm: fresh.searchRadiusKm,
        items: fresh.items,
      );
      final index = _offlinePackages.indexWhere(
        (item) => item.id == targetPackage.id,
      );
      if (index < 0) return;
      _offlinePackages[index] = updated;
      if (_activeOfflinePackageId == updated.id) {
        _offlineResults = updated.items;
        _offlineUpdatedAt = updated.updatedAt;
      }
      _statusMessage =
          'Pacote “${updated.name}” atualizado com ${updated.itemCount} pontos.';
      await _persistNow();
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
      _statusMessage =
          'Não foi possível atualizar o pacote. Os dados salvos foram preservados.';
    } finally {
      _loading = false;
      notifyListeners();
      _routeState.releaseLocationIfIdle();
    }
  }

  Future<void> _saveOfflinePackageFromResults(
    List<RouteExplorerResult> source, {
    required MapRoutePoint current,
    required String name,
    bool notify = true,
    bool persist = true,
  }) async {
    final now = DateTime.now();
    final offlineItems = source
        .map((item) => item.copyWith(source: 'offline'))
        .toList(growable: false);
    final package = OfflinePoiPackage.fromResults(
      id: now.microsecondsSinceEpoch.toString(),
      name: name,
      now: now,
      originLatitude: current.latitude,
      originLongitude: current.longitude,
      searchRadiusKm: _settings.radiusKm,
      items: offlineItems,
    );
    _offlinePackages.insert(0, package);
    _activeOfflinePackageId = package.id;
    _offlineResults = package.items;
    _offlineUpdatedAt = package.updatedAt;
    _statusMessage =
        'Pacote “${package.name}” salvo com ${package.itemCount} pontos.';
    if (notify) notifyListeners();
    if (persist) await _persistNow();
  }

  String _defaultPackageName() {
    final now = DateTime.now().toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'Região ${two(now.day)}/${two(now.month)} '
        '${two(now.hour)}:${two(now.minute)}';
  }

  void _handleRouteChanged() {
    final point = _routeState.current;
    if (point == null || point.recordedAt == _lastHandledRoutePointAt) return;
    _lastHandledRoutePointAt = point.recordedAt;

    var changed = false;
    if (_results.isNotEmpty) {
      _results = _recalculateDistances(
        _results,
        point,
        source: _lastSource == 'offline' ? 'offline' : 'online',
      );
      changed = true;
    } else {
      _selectBestOfflinePackage(point);
      if (_offlineResults.isNotEmpty) {
        _results = _recalculateDistances(
          _offlineResults,
          point,
          source: 'offline',
        );
        changed = true;
      }
    }

    // Distâncias continuam atualizadas a cada ponto para alertas precisos, mas
    // a lista visual não força rebuild a cada amostra do GPS.
    if (changed &&
        MapPerformancePolicy.shouldRefreshPoiUi(
          current: point,
          lastPresented: _lastPoiUiOrigin,
          lastPresentedAt: _lastPoiUiRefreshAt,
        )) {
      _lastPoiUiOrigin = point;
      _lastPoiUiRefreshAt = DateTime.now();
      notifyListeners();
    }
    _evaluateAlerts(point);
    _maybeRefreshAutomatically(point);
  }

  void _maybeRefreshAutomatically(MapRoutePoint current) {
    if (!_settings.searchAheadWhenMoving || _loading || _automaticRefreshScheduled) {
      return;
    }

    final now = DateTime.now();
    final lastAt = _lastAutomaticSearchAt ?? _resultsUpdatedAt;
    final lastOrigin = _lastSearchOrigin;
    final stale = lastAt == null ||
        now.difference(lastAt) >= automaticRefreshInterval;
    final movedMeters = lastOrigin == null
        ? double.infinity
        : LocationTrackingService.distanceMeters(lastOrigin, current);
    final moved = movedMeters >= automaticRefreshDistanceMeters;
    final coverageEdge = lastOrigin == null ||
        movedMeters >= (_settings.radiusKm * 1000 * 0.60);
    final headingChanged = _headingChangedSignificantly(
      _lastSearchHeadingDegrees,
      current.headingDegrees,
    );
    final moving = current.speedKilometersPerHour >=
        automaticRefreshMinimumSpeedKmh;
    if (!moved && !coverageEdge && !(stale && moving) && !(headingChanged && moving)) {
      return;
    }
    if (!MapPerformancePolicy.canAttemptAutomaticPoiRequest(
      lastAttemptAt: _lastAutomaticAttemptAt,
      now: now,
    )) {
      return;
    }

    _lastAutomaticAttemptAt = now;
    _automaticRefreshScheduled = true;
    unawaited(_runAutomaticRefresh());
  }

  bool _headingChangedSignificantly(double? previous, double? current) {
    if (previous == null || current == null) return false;
    var delta = (current - previous).abs() % 360;
    if (delta > 180) delta = 360 - delta;
    return delta >= automaticRefreshHeadingChangeDegrees;
  }

  Future<void> _runAutomaticRefresh() async {
    try {
      await searchNow(requestPermission: false);
    } finally {
      _automaticRefreshScheduled = false;
    }
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
      request.headers.set(HttpHeaders.userAgentHeader, 'VigiaIA/1.0.154');
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
        final metadata = RouteExplorerPoiCatalog.metadataFor(tags);
        if (metadata == null ||
            !_settings.categories.contains(metadata.category)) {
          continue;
        }
        final category = metadata.category;
        if (_settings.searchAheadWhenMoving && !_isAheadOrNearby(current, coordinates)) {
          continue;
        }
        final distanceMeters = _distance.as(
          LengthUnit.Meter,
          origin,
          coordinates,
        );
        final title = metadata.title;
        final uniqueKey =
            '${category.name}:${title.toLowerCase()}:${coordinates.latitude.toStringAsFixed(4)}:${coordinates.longitude.toStringAsFixed(4)}';
        if (!seen.add(uniqueKey)) continue;
        results.add(
          RouteExplorerResult(
            id:
                '${raw['type'] ?? 'item'}-${raw['id'] ?? title.hashCode}-${category.name}',
            category: category,
            title: title,
            subtitle: metadata.subtitle,
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            distanceMeters: distanceMeters,
            address: metadata.address,
            openingHours: metadata.openingHours,
            phone: metadata.phone,
            website: metadata.website,
            operatorName: metadata.operatorName,
            amenities: metadata.amenities,
          ),
        );
      }
      results.sort(
        (a, b) => a.distanceMeters.compareTo(b.distanceMeters),
      );
      return _prioritizeCategoryDiversity(results);
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
    return _prioritizeCategoryDiversity(items);
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
      for (final clause in RouteExplorerPoiCatalog.clausesFor(category)) {
        buffer.writeln(
          'nwr(around:$radiusMeters,$latitude,$longitude)$clause;',
        );
      }
    }
    buffer.write(');out center 160;');
    return buffer.toString();
  }

  List<RouteExplorerResult> _prioritizeCategoryDiversity(
    List<RouteExplorerResult> sortedResults,
  ) {
    if (sortedResults.length <= maximumResults) {
      return List<RouteExplorerResult>.unmodifiable(sortedResults);
    }

    const minimumPerCategory = 2;
    final selected = <RouteExplorerResult>[];
    final selectedIds = <String>{};
    for (final category in _settings.categories) {
      var count = 0;
      for (final item in sortedResults) {
        if (item.category != category || !selectedIds.add(item.id)) continue;
        selected.add(item);
        count++;
        if (count >= minimumPerCategory || selected.length >= maximumResults) {
          break;
        }
      }
      if (selected.length >= maximumResults) break;
    }

    for (final item in sortedResults) {
      if (selected.length >= maximumResults) break;
      if (selectedIds.add(item.id)) selected.add(item);
    }
    selected.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return List<RouteExplorerResult>.unmodifiable(selected);
  }

  void _pruneDeliveredAlerts(List<RouteExplorerResult> results) {
    final activeIds = results.map((item) => item.id).toSet();
    _deliveredThresholds.removeWhere((id, _) => !activeIds.contains(id));
  }

  void _evaluateAlerts(MapRoutePoint current) {
    final activeResults = _results.isNotEmpty ? _results : _offlineResults;
    final decision = _alertPolicy.select(
      results: activeResults,
      settings: _settings,
      deliveredThresholds: _deliveredThresholds,
      now: DateTime.now(),
      lastDeliveredAt: _lastAlertDeliveredAt,
      directionFilter: _settings.searchAheadWhenMoving
          ? (item) => _isAheadOrNearby(
                current,
                LatLng(item.latitude, item.longitude),
              )
          : null,
    );
    if (decision == null) return;

    final delivered = _deliveredThresholds.putIfAbsent(
      decision.item.id,
      () => <int>{},
    );
    delivered.addAll(decision.consumedThresholds);
    _lastAlertDeliveredAt = DateTime.now();
    unawaited(
      _alerts.deliver(
        _buildAlertMessage(decision.item, decision.item.distanceMeters),
        title: 'Mapa e percurso',
      ),
    );
  }

  String _buildAlertMessage(RouteExplorerResult item, double distanceMeters) {
    final prefix = switch (item.category) {
      RouteExplorerCategory.fuel => 'Próximo posto',
      RouteExplorerCategory.restaurant => 'Próximo restaurante',
      RouteExplorerCategory.stop => 'Próxima parada',
      RouteExplorerCategory.workshop => 'Oficina de bicicleta',
      RouteExplorerCategory.health => 'Próximo ponto de saúde',
      RouteExplorerCategory.water => 'Água ou banheiro',
      RouteExplorerCategory.camping => 'Próximo camping',
      RouteExplorerCategory.viewpoint => 'Próximo mirante',
      RouteExplorerCategory.waterfall => 'Próxima cachoeira',
      RouteExplorerCategory.market => 'Próximo mercado',
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
      _offlinePackages.clear();
      final rawPackages = (decoded['offlinePackages'] as List?) ?? const <Object>[];
      for (final raw in rawPackages.whereType<Map>()) {
        final package = OfflinePoiPackage.fromJson(
          raw.map((key, value) => MapEntry(key.toString(), value)),
        );
        if (package.id.isNotEmpty && package.items.isNotEmpty) {
          _offlinePackages.add(package);
        }
      }
      _activeOfflinePackageId = decoded['activeOfflinePackageId'] as String?;

      // Migração transparente do formato legado: uma única lista global.
      if (_offlinePackages.isEmpty) {
        final legacyItems = ((decoded['offlineResults'] as List?) ?? const <Object>[])
            .whereType<Map>()
            .map(
              (item) => RouteExplorerResult.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
              ),
            )
            .toList(growable: false);
        if (legacyItems.isNotEmpty) {
          final updatedAt = DateTime.tryParse(
                decoded['offlineUpdatedAt'] as String? ?? '',
              ) ??
              DateTime.now();
          final originLat = legacyItems.first.latitude;
          final originLon = legacyItems.first.longitude;
          final migrated = OfflinePoiPackage.fromResults(
            id: 'legacy-${updatedAt.millisecondsSinceEpoch}',
            name: 'Lista offline antiga',
            now: updatedAt,
            originLatitude: originLat,
            originLongitude: originLon,
            searchRadiusKm: _settings.radiusKm,
            items: legacyItems
                .map((item) => item.copyWith(source: 'offline'))
                .toList(growable: false),
          );
          _offlinePackages.add(migrated);
          _activeOfflinePackageId = migrated.id;
        }
      }
      _syncActiveOfflineCache();
      final resultsUpdatedAt = decoded['resultsUpdatedAt'] as String?;
      final offlineUpdatedAt = decoded['offlineUpdatedAt'] as String?;
      _resultsUpdatedAt = resultsUpdatedAt == null
          ? null
          : DateTime.tryParse(resultsUpdatedAt);
      _offlineUpdatedAt = activeOfflinePackage?.updatedAt ??
          (offlineUpdatedAt == null ? null : DateTime.tryParse(offlineUpdatedAt));
      _lastSource = decoded['lastSource'] as String? ?? 'none';
      _statusMessage = decoded['statusMessage'] as String?;
    } catch (_) {
      // Ignora restauracao corrompida.
    }
  }

  void _syncActiveOfflineCache() {
    OfflinePoiPackage? selected = activeOfflinePackage;
    if (selected == null && _offlinePackages.isNotEmpty) {
      selected = _offlinePackages.first;
      _activeOfflinePackageId = selected.id;
    }
    _offlineResults = selected?.items ?? const <RouteExplorerResult>[];
    _offlineUpdatedAt = selected?.updatedAt;
  }

  OfflinePoiPackage? _selectBestOfflinePackage(MapRoutePoint current) {
    if (_offlinePackages.isEmpty) {
      _activeOfflinePackageId = null;
      _offlineResults = const <RouteExplorerResult>[];
      _offlineUpdatedAt = null;
      return null;
    }
    OfflinePoiPackage? best;
    for (final package in _offlinePackages) {
      if (package.contains(
        latitude: current.latitude,
        longitude: current.longitude,
      )) {
        if (best == null || package.updatedAt.isAfter(best.updatedAt)) {
          best = package;
        }
      }
    }
    best ??= _nearestOfflinePackage(current);
    if (best != null && best.id != _activeOfflinePackageId) {
      _activeOfflinePackageId = best.id;
      _offlineResults = best.items;
      _offlineUpdatedAt = best.updatedAt;
    }
    return best;
  }

  OfflinePoiPackage? _nearestOfflinePackage(MapRoutePoint current) {
    OfflinePoiPackage? best;
    double bestMeters = double.infinity;
    final origin = LatLng(current.latitude, current.longitude);
    for (final package in _offlinePackages) {
      final meters = _distance.as(
        LengthUnit.Meter,
        origin,
        LatLng(package.originLatitude, package.originLongitude),
      );
      if (meters < bestMeters) {
        bestMeters = meters;
        best = package;
      }
    }
    if (best == null) return null;
    if (!MapBikeConsolidationPolicy.canUseOfflinePoiPackageFallback(
      package: best,
      distanceMeters: bestMeters,
    )) {
      return null;
    }
    return best;
  }

  Future<void> _persistNow() async {
    final file = _file;
    if (file == null) return;
    final temporary = File('${file.path}.tmp');
    final payload = <String, Object?>{
      'version': 2,
      'settings': _settings.toJson(),
      'results': _results.map((item) => item.toJson()).toList(growable: false),
      'offlinePackages':
          _offlinePackages.map((item) => item.toJson()).toList(growable: false),
      'activeOfflinePackageId': _activeOfflinePackageId,
      // Compatibilidade de leitura com versões anteriores durante rollback.
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
