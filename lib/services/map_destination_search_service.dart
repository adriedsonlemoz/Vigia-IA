import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../models/map_destination_search.dart';
import '../models/map_route_point.dart';
import '../models/offline_map_package.dart';
import '../models/offline_poi_package.dart';
import '../models/route_explorer_models.dart';

class MapDestinationSearchService extends ChangeNotifier {
  MapDestinationSearchService._();

  static final MapDestinationSearchService instance =
      MapDestinationSearchService._();

  static const double nearbyRadiusKm = 180;
  static const double quickNearbyRadiusKm = 65;
  static const Duration nearbyRefreshAge = Duration(days: 3);
  static const Duration cacheRetention = Duration(days: 60);
  static const int maximumSuggestions = 18;
  static const int maximumResults = 30;

  final Distance _distance = const Distance();
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10)
    ..idleTimeout = const Duration(seconds: 12);

  File? _file;
  bool _initialized = false;
  bool _suggestionsLoading = false;
  bool _searchLoading = false;
  bool _nearbyRefreshInFlight = false;
  String? _suggestionsStatusMessage;
  String? _searchStatusMessage;
  List<MapDestinationSearchResult> _knownPlaces =
      const <MapDestinationSearchResult>[];
  List<MapDestinationSearchResult> _suggestions =
      const <MapDestinationSearchResult>[];
  List<MapDestinationSearchResult> _results =
      const <MapDestinationSearchResult>[];
  DateTime? _nearbyUpdatedAt;
  LatLng? _nearbyOrigin;
  DateTime? _lastNominatimRequestAt;

  bool get loading => _suggestionsLoading || _searchLoading;
  bool get suggestionsLoading => _suggestionsLoading;
  bool get searchLoading => _searchLoading;
  String? get statusMessage => _searchStatusMessage ?? _suggestionsStatusMessage;
  String? get suggestionsStatusMessage => _suggestionsStatusMessage;
  String? get searchStatusMessage => _searchStatusMessage;
  List<MapDestinationSearchResult> get suggestions =>
      List<MapDestinationSearchResult>.unmodifiable(_suggestions);
  List<MapDestinationSearchResult> get results =>
      List<MapDestinationSearchResult>.unmodifiable(_results);

  Future<void> initialize() async {
    if (_initialized) return;
    final root = await getApplicationSupportDirectory();
    _file = File(
      '${root.path}${Platform.pathSeparator}map_destination_search_index.json',
    );
    await _restore();
    _initialized = true;
  }

  Future<void> prepareSuggestions({
    required MapRoutePoint current,
    required bool onlineAllowed,
    required List<OfflineMapPackage> offlineMaps,
  }) async {
    await initialize();
    _suggestions = _buildLocalSuggestions(
      current: current,
      offlineMaps: offlineMaps,
      onlyDownloaded: !onlineAllowed,
    );
    notifyListeners();

    if (!onlineAllowed || !_needsNearbyRefresh(current)) {
      _suggestionsStatusMessage = onlineAllowed
          ? 'Sugestões locais prontas.'
          : 'Offline · pesquisando somente dados salvos.';
      notifyListeners();
      return;
    }
    if (_nearbyRefreshInFlight) {
      _suggestionsStatusMessage = _suggestions.isEmpty
          ? 'Atualizando cidades próximas em segundo plano…'
          : 'Sugestões salvas prontas · atualização regional em andamento.';
      notifyListeners();
      return;
    }

    _nearbyRefreshInFlight = true;
    _setSuggestionsLoading(true);
    try {
      final quick = await _fetchNearbyPlaces(
        current,
        radiusKm: quickNearbyRadiusKm,
        timeout: const Duration(seconds: 5),
        maximumItems: 80,
      ).timeout(const Duration(seconds: 5));
      _mergeKnownPlaces(quick);
      _suggestions = _buildLocalSuggestions(
        current: current,
        offlineMaps: offlineMaps,
        onlyDownloaded: false,
      );
      _suggestionsStatusMessage = quick.isEmpty
          ? (_suggestions.isEmpty
              ? 'Buscando uma região maior em segundo plano…'
              : 'Sugestões salvas prontas · ampliando a região em segundo plano…')
          : 'Sugestões próximas prontas.';
      notifyListeners();
      _setSuggestionsLoading(false);

      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (_suggestions.length < maximumSuggestions && !_searchLoading) {
        try {
          final expanded = await _fetchNearbyPlaces(
            current,
            radiusKm: nearbyRadiusKm,
            timeout: const Duration(seconds: 9),
            maximumItems: 120,
          );
          _mergeKnownPlaces(expanded);
          _suggestions = _buildLocalSuggestions(
            current: current,
            offlineMaps: offlineMaps,
            onlyDownloaded: false,
          );
        } catch (_) {
          // A fase curta já liberou a interface. A ampliação é best-effort.
        }
      }
      _nearbyUpdatedAt = DateTime.now();
      _nearbyOrigin = LatLng(current.latitude, current.longitude);
      _suggestionsStatusMessage = _suggestions.isEmpty
          ? 'Nenhuma cidade/comunidade encontrada nesta região.'
          : 'Cidades e comunidades próximas prontas.';
      await _persist();
      notifyListeners();
    } catch (_) {
      _suggestionsStatusMessage = _suggestions.isEmpty
          ? 'Não foi possível atualizar cidades próximas agora.'
          : 'Usando sugestões já salvas.';
      notifyListeners();
    } finally {
      _nearbyRefreshInFlight = false;
      _setSuggestionsLoading(false);
    }
  }

  Future<List<MapDestinationSearchResult>> placesAlongRoute({
    required List<LatLng> route,
    required MapRoutePoint current,
    required bool onlineAllowed,
    required List<OfflineMapPackage> offlineMaps,
    required List<OfflinePoiPackage> offlinePoiPackages,
  }) async {
    await initialize();
    if (route.length < 2) return const <MapDestinationSearchResult>[];
    final localPlaces = _knownPlaces
        .map(
          (place) => _withDistanceAndOfflineSource(
            place,
            current: current,
            offlineMaps: offlineMaps,
          ),
        )
        .where((place) => onlineAllowed || place.offline);
    final local = <MapDestinationSearchResult>[
      ...localPlaces,
      for (final package in offlinePoiPackages)
        for (final poi in package.items)
          if (poi.category.name == 'camping' || poi.category.name == 'stop')
            MapDestinationSearchResult(
              id: 'poi:${poi.id}',
              title: poi.title,
              subtitle: poi.subtitle.trim().isEmpty
                  ? poi.category.label
                  : '${poi.category.label} · ${poi.subtitle}',
              latitude: poi.latitude,
              longitude: poi.longitude,
              distanceMeters: _meters(
                current.latitude,
                current.longitude,
                poi.latitude,
                poi.longitude,
              ),
              kind: MapDestinationKind.pointOfInterest,
              source: 'offline',
              poiCategory: poi.category,
            ),
    ];
    if (!onlineAllowed) return _dedupeAndSort(local);
    try {
      final remote = await _fetchRoutePlaces(route, current);
      _mergeKnownPlaces(
        remote.where((item) => item.kind != MapDestinationKind.pointOfInterest),
      );
      await _persist();
      return _dedupeAndSort(<MapDestinationSearchResult>[...local, ...remote]);
    } catch (_) {
      return _dedupeAndSort(local);
    }
  }

  Future<void> indexOfflineMapPackage(OfflineMapPackage package) async {
    if (!package.hasBounds) return;
    await initialize();
    try {
      final fetched = await _fetchPlacesInBounds(package);
      if (fetched.isEmpty) return;
      _mergeKnownPlaces(fetched);
      await _persist();
    } catch (_) {
      // O mapa baixado continua válido mesmo se o índice de pesquisa falhar.
    }
  }

  void updateLocalQuery({
    required String query,
    required MapRoutePoint current,
    required List<OfflineMapPackage> offlineMaps,
    required List<OfflinePoiPackage> offlinePoiPackages,
    required bool onlyDownloaded,
  }) {
    final text = query.trim();
    if (text.isEmpty) {
      _results = const <MapDestinationSearchResult>[];
      _searchStatusMessage = null;
      notifyListeners();
      return;
    }

    final matches = _searchLocal(
      text,
      current: current,
      offlineMaps: offlineMaps,
      offlinePoiPackages: offlinePoiPackages,
      onlyDownloaded: onlyDownloaded,
    );
    final needle = _fold(text);
    final ranked = matches.toList(growable: false)
      ..sort((a, b) {
        int score(MapDestinationSearchResult item) {
          var value = 0;
          final title = _fold(item.title);
          if (title == needle) value += 1000;
          if (title.startsWith(needle)) value += 500;
          if (item.kind != MapDestinationKind.pointOfInterest) value += 120;
          if (item.offline) value += 80;
          if (item.source == 'cache') value += 60;
          return value;
        }

        final byScore = score(b).compareTo(score(a));
        return byScore != 0
            ? byScore
            : a.distanceMeters.compareTo(b.distanceMeters);
      });
    _results = ranked.take(maximumSuggestions).toList(growable: false);
    _searchStatusMessage = _results.isEmpty
        ? 'Nenhuma sugestão local para “$text”. Confirme para pesquisar online.'
        : '${_results.length} sugestão(ões) local(is) · confirme para ampliar online.';
    notifyListeners();
  }

  Future<void> searchSubmitted({
    required String query,
    required MapRoutePoint current,
    required bool onlineAllowed,
    required List<OfflineMapPackage> offlineMaps,
    required List<OfflinePoiPackage> offlinePoiPackages,
  }) async {
    await initialize();
    final text = query.trim();
    if (text.length < 2) {
      _results = const <MapDestinationSearchResult>[];
      _searchStatusMessage = 'Digite pelo menos 2 caracteres.';
      notifyListeners();
      return;
    }

    final local = _searchLocal(
      text,
      current: current,
      offlineMaps: offlineMaps,
      offlinePoiPackages: offlinePoiPackages,
      onlyDownloaded: !onlineAllowed,
    );
    _results = local;
    _searchStatusMessage = onlineAllowed
        ? 'Pesquisando também online…'
        : 'Offline · resultados limitados ao que está salvo.';
    notifyListeners();

    if (!onlineAllowed) return;
    _setSearchLoading(true);
    try {
      final remote = await _fetchNominatim(
        text,
        current,
      ).timeout(const Duration(seconds: 10));
      _mergeKnownPlaces(remote.where((item) => item.kind != MapDestinationKind.pointOfInterest));
      _results = _dedupeAndSort(<MapDestinationSearchResult>[
        ...local,
        ...remote,
      ]).take(maximumResults).toList(growable: false);
      _searchStatusMessage = _results.isEmpty
          ? 'Nenhum resultado encontrado.'
          : '${_results.length} resultado(s) · online + dados salvos.';
      await _persist();
    } on TimeoutException {
      _searchStatusMessage = local.isEmpty
          ? 'A pesquisa online demorou demais.'
          : 'Pesquisa online indisponível · mostrando dados salvos.';
    } on SocketException {
      _searchStatusMessage = local.isEmpty
          ? 'Sem internet e sem resultado offline para esta busca.'
          : 'Sem internet · mostrando dados salvos.';
    } catch (_) {
      _searchStatusMessage = local.isEmpty
          ? 'Não foi possível concluir a pesquisa.'
          : 'Mostrando resultados salvos.';
    } finally {
      _setSearchLoading(false);
    }
  }

  List<MapDestinationSearchResult> _buildLocalSuggestions({
    required MapRoutePoint current,
    required List<OfflineMapPackage> offlineMaps,
    required bool onlyDownloaded,
  }) {
    final places = _knownPlaces
        .map(
          (item) => _withDistanceAndOfflineSource(
            item,
            current: current,
            offlineMaps: offlineMaps,
          ),
        )
        .where((item) => item.distanceMeters <= nearbyRadiusKm * 1000)
        .where((item) => !onlyDownloaded || item.offline)
        .where((item) => item.kind != MapDestinationKind.pointOfInterest)
        .toList(growable: true);
    places.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return places.take(maximumSuggestions).toList(growable: false);
  }

  List<MapDestinationSearchResult> _searchLocal(
    String query, {
    required MapRoutePoint current,
    required List<OfflineMapPackage> offlineMaps,
    required List<OfflinePoiPackage> offlinePoiPackages,
    required bool onlyDownloaded,
  }) {
    final needle = _fold(query);
    final found = <MapDestinationSearchResult>[];

    for (final place in _knownPlaces) {
      if (!_matches(needle, place.title, place.subtitle)) continue;
      final resolved = _withDistanceAndOfflineSource(
        place,
        current: current,
        offlineMaps: offlineMaps,
      );
      if (!onlyDownloaded || resolved.offline) found.add(resolved);
    }

    final poiIds = <String>{};
    for (final package in offlinePoiPackages) {
      for (final poi in package.items) {
        if (!poiIds.add(poi.id)) continue;
        if (!_matches(needle, poi.title, poi.subtitle, poi.category.label)) {
          continue;
        }
        found.add(
          MapDestinationSearchResult(
            id: 'poi:${poi.id}',
            title: poi.title,
            subtitle: poi.subtitle.trim().isEmpty
                ? poi.category.label
                : '${poi.category.label} · ${poi.subtitle}',
            latitude: poi.latitude,
            longitude: poi.longitude,
            distanceMeters: _meters(
              current.latitude,
              current.longitude,
              poi.latitude,
              poi.longitude,
            ),
            kind: MapDestinationKind.pointOfInterest,
            source: 'offline',
            poiCategory: poi.category,
          ),
        );
      }
    }

    return _dedupeAndSort(found).take(maximumResults).toList(growable: false);
  }

  Future<List<MapDestinationSearchResult>> _fetchRoutePlaces(
    List<LatLng> route,
    MapRoutePoint current,
  ) async {
    final sampleCount = route.length.clamp(2, 8).toInt();
    final indexes = <int>{};
    for (var index = 0; index < sampleCount; index++) {
      final fraction = sampleCount == 1 ? 0.0 : index / (sampleCount - 1);
      indexes.add((fraction * (route.length - 1)).round());
    }
    final query = StringBuffer('[out:json][timeout:20];(');
    for (final index in indexes) {
      final point = route[index];
      query.write(
        'nwr(around:20000,${point.latitude},${point.longitude})'
        '["place"~"city|town|village|hamlet"];',
      );
      query.write(
        'nwr(around:12000,${point.latitude},${point.longitude})'
        '["tourism"="camp_site"];',
      );
    }
    query.write(');out center 180;');
    final request = await _client
        .postUrl(Uri.parse('https://overpass-api.de/api/interpreter'))
        .timeout(const Duration(seconds: 8));
    request.headers.set(HttpHeaders.userAgentHeader, 'VigiaIA/1.0.185');
    request.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
      charset: 'utf-8',
    );
    request.write('data=${Uri.encodeQueryComponent(query.toString())}');
    final response = await request.close().timeout(const Duration(seconds: 22));
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Overpass HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map) return const <MapDestinationSearchResult>[];
    final elements = decoded['elements'];
    if (elements is! List) return const <MapDestinationSearchResult>[];
    final results = <MapDestinationSearchResult>[];
    for (final raw in elements.whereType<Map>()) {
      final item = raw.cast<String, dynamic>();
      final tagsRaw = item['tags'];
      if (tagsRaw is! Map) continue;
      final tags = tagsRaw.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
      final name = tags['name']?.trim();
      if (name == null || name.isEmpty) continue;
      final center = item['center'];
      final lat = (item['lat'] as num?)?.toDouble() ??
          (center is Map ? (center['lat'] as num?)?.toDouble() : null);
      final lon = (item['lon'] as num?)?.toDouble() ??
          (center is Map ? (center['lon'] as num?)?.toDouble() : null);
      if (lat == null || lon == null) continue;
      final isCamping = tags['tourism'] == 'camp_site';
      final placeType = tags['place'];
      results.add(
        MapDestinationSearchResult(
          id: 'route-osm:${item['type']}:${item['id']}',
          title: name,
          subtitle: isCamping
              ? 'Camping'
              : MapDestinationKindX.fromOsmType(placeType).label,
          latitude: lat,
          longitude: lon,
          distanceMeters: _meters(
            current.latitude,
            current.longitude,
            lat,
            lon,
          ),
          kind: isCamping
              ? MapDestinationKind.pointOfInterest
              : MapDestinationKindX.fromOsmType(placeType),
          source: 'online',
        ),
      );
    }
    return _dedupeAndSort(results);
  }

  Future<List<MapDestinationSearchResult>> _fetchPlacesInBounds(
    OfflineMapPackage package,
  ) async {
    final south = package.south;
    final west = package.west;
    final north = package.north;
    final east = package.east;
    if (south == null || west == null || north == null || east == null) {
      return const <MapDestinationSearchResult>[];
    }
    final query = '[out:json][timeout:18];('
        'nwr($south,$west,$north,$east)'
        '["place"~"city|town|village|hamlet"];'
        ');out center 250;';
    final request = await _client
        .postUrl(Uri.parse('https://overpass-api.de/api/interpreter'))
        .timeout(const Duration(seconds: 8));
    request.headers.set(HttpHeaders.userAgentHeader, 'VigiaIA/1.0.185');
    request.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
      charset: 'utf-8',
    );
    request.write('data=${Uri.encodeQueryComponent(query)}');
    final response = await request.close().timeout(const Duration(seconds: 20));
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Overpass HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map) return const <MapDestinationSearchResult>[];
    final elements = decoded['elements'];
    if (elements is! List) return const <MapDestinationSearchResult>[];
    final results = <MapDestinationSearchResult>[];
    for (final raw in elements.whereType<Map>()) {
      final item = raw.cast<String, dynamic>();
      final tagsRaw = item['tags'];
      if (tagsRaw is! Map) continue;
      final tags = tagsRaw.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
      final name = tags['name']?.trim();
      if (name == null || name.isEmpty) continue;
      final center = item['center'];
      final lat = (item['lat'] as num?)?.toDouble() ??
          (center is Map ? (center['lat'] as num?)?.toDouble() : null);
      final lon = (item['lon'] as num?)?.toDouble() ??
          (center is Map ? (center['lon'] as num?)?.toDouble() : null);
      if (lat == null || lon == null) continue;
      final placeType = tags['place'];
      results.add(
        MapDestinationSearchResult(
          id: 'offline-index:${item['type']}:${item['id']}',
          title: name,
          subtitle: MapDestinationKindX.fromOsmType(placeType).label,
          latitude: lat,
          longitude: lon,
          distanceMeters: 0,
          kind: MapDestinationKindX.fromOsmType(placeType),
          source: 'cache',
        ),
      );
    }
    return _dedupeAndSort(results);
  }

  Future<List<MapDestinationSearchResult>> _fetchNearbyPlaces(
    MapRoutePoint current, {
    required double radiusKm,
    required Duration timeout,
    required int maximumItems,
  }) async {
    final radiusMeters = (radiusKm * 1000).round();
    final queryTimeout = math.max(4, timeout.inSeconds - 1);
    final query = '[out:json][timeout:$queryTimeout];'
        'node(around:$radiusMeters,${current.latitude},${current.longitude})'
        '["place"~"city|town|village|hamlet"]["name"];'
        'out body $maximumItems;';
    final request = await _client
        .postUrl(Uri.parse('https://overpass-api.de/api/interpreter'))
        .timeout(const Duration(seconds: 5));
    request.headers.set(HttpHeaders.userAgentHeader, 'VigiaIA/1.0.185');
    request.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
      charset: 'utf-8',
    );
    request.write('data=${Uri.encodeQueryComponent(query)}');
    final response = await request.close().timeout(timeout);
    final body = await utf8.decoder.bind(response).join().timeout(timeout);
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Overpass HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map) return const <MapDestinationSearchResult>[];
    final elements = decoded['elements'];
    if (elements is! List) return const <MapDestinationSearchResult>[];
    final results = <MapDestinationSearchResult>[];
    for (final raw in elements.whereType<Map>()) {
      final item = raw.cast<String, dynamic>();
      final tagsRaw = item['tags'];
      if (tagsRaw is! Map) continue;
      final tags = tagsRaw.map((key, value) => MapEntry(key.toString(), value.toString()));
      final name = tags['name']?.trim();
      if (name == null || name.isEmpty) continue;
      final center = item['center'];
      final lat = (item['lat'] as num?)?.toDouble() ??
          (center is Map ? (center['lat'] as num?)?.toDouble() : null);
      final lon = (item['lon'] as num?)?.toDouble() ??
          (center is Map ? (center['lon'] as num?)?.toDouble() : null);
      if (lat == null || lon == null) continue;
      final placeType = tags['place'];
      final state = tags['addr:state'] ?? tags['state'];
      final subtitleParts = <String>[
        MapDestinationKindX.fromOsmType(placeType).label,
        if (state != null && state.trim().isNotEmpty) state.trim(),
      ];
      results.add(
        MapDestinationSearchResult(
          id: 'osm:${item['type']}:${item['id']}',
          title: name,
          subtitle: subtitleParts.join(' · '),
          latitude: lat,
          longitude: lon,
          distanceMeters: _meters(
            current.latitude,
            current.longitude,
            lat,
            lon,
          ),
          kind: MapDestinationKindX.fromOsmType(placeType),
          source: 'online',
        ),
      );
    }
    return _dedupeAndSort(results);
  }

  Future<MapDestinationSearchResult> reverseLookup({
    required LatLng point,
    required MapRoutePoint current,
    required bool onlineAllowed,
    required List<OfflinePoiPackage> offlinePoiPackages,
  }) async {
    await initialize();
    final localCandidates = <MapDestinationSearchResult>[
      ..._knownPlaces,
      for (final package in offlinePoiPackages)
        for (final poi in package.items)
          MapDestinationSearchResult(
            id: 'poi:${poi.id}',
            title: poi.title,
            subtitle: poi.address?.trim().isNotEmpty == true
                ? poi.address!.trim()
                : poi.subtitle,
            latitude: poi.latitude,
            longitude: poi.longitude,
            distanceMeters: _meters(
              current.latitude,
              current.longitude,
              poi.latitude,
              poi.longitude,
            ),
            kind: MapDestinationKind.pointOfInterest,
            source: 'offline',
            poiCategory: poi.category,
          ),
    ];
    MapDestinationSearchResult? nearest;
    double nearestToTap = double.infinity;
    for (final item in localCandidates) {
      final distance = _meters(
        point.latitude,
        point.longitude,
        item.latitude,
        item.longitude,
      );
      if (distance < nearestToTap) {
        nearestToTap = distance;
        nearest = item;
      }
    }
    if (nearest != null && nearestToTap <= 120) {
      return nearest.copyWith(
        distanceMeters: _meters(
          current.latitude,
          current.longitude,
          nearest.latitude,
          nearest.longitude,
        ),
      );
    }

    if (onlineAllowed) {
      try {
        await _respectNominatimRateLimit();
        final uri = Uri.https(
          'nominatim.openstreetmap.org',
          '/reverse',
          <String, String>{
            'lat': point.latitude.toString(),
            'lon': point.longitude.toString(),
            'format': 'jsonv2',
            'addressdetails': '1',
            'zoom': '18',
            'accept-language': 'pt-BR,pt,en',
          },
        );
        final request = await _client.getUrl(uri).timeout(const Duration(seconds: 6));
        request.headers.set(
          HttpHeaders.userAgentHeader,
          'VigiaIA/1.0.185 map-reverse-search',
        );
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        final response = await request.close().timeout(const Duration(seconds: 8));
        final body = await utf8.decoder.bind(response).join();
        _lastNominatimRequestAt = DateTime.now();
        if (response.statusCode == HttpStatus.ok) {
          final decoded = jsonDecode(body);
          if (decoded is Map) {
            final item = decoded.cast<String, dynamic>();
            final displayName = item['display_name']?.toString().trim() ?? '';
            final addressRaw = item['address'];
            final address = addressRaw is Map
                ? addressRaw.map(
                    (key, value) => MapEntry(key.toString(), value.toString()),
                  )
                : const <String, String>{};
            final title = _bestTitle(address, displayName);
            final type = item['type']?.toString();
            final category = item['category']?.toString();
            final kind = category == 'place'
                ? MapDestinationKindX.fromOsmType(type)
                : MapDestinationKind.place;
            return MapDestinationSearchResult(
              id: 'reverse:${item['osm_type']}:${item['osm_id']}',
              title: title.isEmpty ? 'Local selecionado' : title,
              subtitle: displayName.isEmpty ? 'Endereço aproximado indisponível' : displayName,
              latitude: point.latitude,
              longitude: point.longitude,
              distanceMeters: _meters(
                current.latitude,
                current.longitude,
                point.latitude,
                point.longitude,
              ),
              kind: kind,
              source: 'online',
            );
          }
        }
      } catch (_) {
        // Coordenadas continuam utilizáveis mesmo sem geocodificação reversa.
      }
    }

    return MapDestinationSearchResult(
      id: 'coordinate:${point.latitude.toStringAsFixed(5)}:${point.longitude.toStringAsFixed(5)}',
      title: 'Local selecionado',
      subtitle:
          '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
      latitude: point.latitude,
      longitude: point.longitude,
      distanceMeters: _meters(
        current.latitude,
        current.longitude,
        point.latitude,
        point.longitude,
      ),
      kind: MapDestinationKind.place,
      source: onlineAllowed ? 'coordinate' : 'offline',
    );
  }

  Future<List<MapDestinationSearchResult>> _fetchNominatim(
    String query,
    MapRoutePoint current,
  ) async {
    await _respectNominatimRateLimit();
    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      <String, String>{
        'q': query,
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '12',
        'accept-language': 'pt-BR,pt,en',
      },
    );
    final request = await _client.getUrl(uri).timeout(const Duration(seconds: 8));
    request.headers.set(HttpHeaders.userAgentHeader, 'VigiaIA/1.0.185 map-search');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 15));
    final body = await utf8.decoder.bind(response).join();
    _lastNominatimRequestAt = DateTime.now();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Nominatim HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(body);
    if (decoded is! List) return const <MapDestinationSearchResult>[];
    final results = <MapDestinationSearchResult>[];
    for (final raw in decoded.whereType<Map>()) {
      final item = raw.cast<String, dynamic>();
      final lat = double.tryParse(item['lat']?.toString() ?? '');
      final lon = double.tryParse(item['lon']?.toString() ?? '');
      if (lat == null || lon == null) continue;
      final displayName = item['display_name']?.toString().trim() ?? '';
      final addressRaw = item['address'];
      final address = addressRaw is Map
          ? addressRaw.map((key, value) => MapEntry(key.toString(), value.toString()))
          : const <String, String>{};
      final type = item['type']?.toString();
      final category = item['category']?.toString();
      final title = _bestTitle(address, displayName);
      final kind = category == 'place'
          ? MapDestinationKindX.fromOsmType(type)
          : MapDestinationKind.pointOfInterest;
      results.add(
        MapDestinationSearchResult(
          id: 'nominatim:${item['osm_type']}:${item['osm_id']}',
          title: title,
          subtitle: displayName == title ? kind.label : displayName,
          latitude: lat,
          longitude: lon,
          distanceMeters: _meters(
            current.latitude,
            current.longitude,
            lat,
            lon,
          ),
          kind: kind,
          source: 'online',
        ),
      );
    }
    return _dedupeAndSort(results);
  }

  String _bestTitle(Map<String, String> address, String displayName) {
    for (final key in const <String>[
      'amenity',
      'shop',
      'tourism',
      'city',
      'town',
      'village',
      'hamlet',
      'municipality',
      'road',
    ]) {
      final value = address[key]?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    final comma = displayName.indexOf(',');
    return comma > 0 ? displayName.substring(0, comma).trim() : displayName;
  }

  Future<void> _respectNominatimRateLimit() async {
    final last = _lastNominatimRequestAt;
    if (last == null) return;
    final elapsed = DateTime.now().difference(last);
    const minimum = Duration(milliseconds: 1100);
    if (elapsed < minimum) await Future<void>.delayed(minimum - elapsed);
  }

  bool _needsNearbyRefresh(MapRoutePoint current) {
    final updatedAt = _nearbyUpdatedAt;
    final origin = _nearbyOrigin;
    if (updatedAt == null || origin == null) return true;
    if (DateTime.now().difference(updatedAt) > nearbyRefreshAge) return true;
    return _distance.as(
          LengthUnit.Kilometer,
          origin,
          LatLng(current.latitude, current.longitude),
        ) >
        40;
  }

  MapDestinationSearchResult _withDistanceAndOfflineSource(
    MapDestinationSearchResult item, {
    required MapRoutePoint current,
    required List<OfflineMapPackage> offlineMaps,
  }) {
    final saved = offlineMaps.any(
      (package) =>
          package.hasBounds &&
          package.contains(
            latitude: item.latitude,
            longitude: item.longitude,
          ),
    );
    return item.copyWith(
      distanceMeters: _meters(
        current.latitude,
        current.longitude,
        item.latitude,
        item.longitude,
      ),
      source: saved ? 'offline' : item.source,
    );
  }

  double _meters(double lat1, double lon1, double lat2, double lon2) {
    return _distance.as(
      LengthUnit.Meter,
      LatLng(lat1, lon1),
      LatLng(lat2, lon2),
    );
  }

  bool _matches(String needle, String title, String subtitle, [String extra = '']) {
    final haystack = _fold('$title $subtitle $extra');
    return haystack.contains(needle);
  }

  String _fold(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c')
        .trim();
  }

  List<MapDestinationSearchResult> _dedupeAndSort(
    Iterable<MapDestinationSearchResult> source,
  ) {
    final byKey = <String, MapDestinationSearchResult>{};
    for (final item in source) {
      final key = '${_fold(item.title)}:'
          '${item.latitude.toStringAsFixed(4)}:'
          '${item.longitude.toStringAsFixed(4)}';
      final existing = byKey[key];
      if (existing == null || (item.offline && !existing.offline)) {
        byKey[key] = item;
      }
    }
    final values = byKey.values.toList(growable: false)
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return values;
  }

  void _mergeKnownPlaces(Iterable<MapDestinationSearchResult> source) {
    final merged = <String, MapDestinationSearchResult>{};
    for (final item in source) {
      if (item.id.isEmpty) continue;
      merged[item.id] = item.copyWith(source: 'cache');
    }
    for (final item in _knownPlaces) {
      merged.putIfAbsent(item.id, () => item);
    }
    _knownPlaces = merged.values.take(600).toList(growable: false);
  }

  void _setSuggestionsLoading(bool value) {
    if (_suggestionsLoading == value) return;
    _suggestionsLoading = value;
    notifyListeners();
  }

  void _setSearchLoading(bool value) {
    if (_searchLoading == value) return;
    _searchLoading = value;
    notifyListeners();
  }

  Future<void> _restore() async {
    final file = _file;
    if (file == null || !await file.exists()) return;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return;
      final map = decoded.cast<String, dynamic>();
      final updatedAt = DateTime.tryParse(map['nearbyUpdatedAt'] as String? ?? '');
      final origin = map['nearbyOrigin'];
      _nearbyUpdatedAt = updatedAt;
      if (origin is Map) {
        final lat = (origin['latitude'] as num?)?.toDouble();
        final lon = (origin['longitude'] as num?)?.toDouble();
        if (lat != null && lon != null) _nearbyOrigin = LatLng(lat, lon);
      }
      final now = DateTime.now();
      final rawPlaces = (map['places'] as List?) ?? const <Object>[];
      _knownPlaces = rawPlaces
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .where((item) {
            final cachedAt = DateTime.tryParse(item['cachedAt'] as String? ?? '');
            return cachedAt == null || now.difference(cachedAt) <= cacheRetention;
          })
          .map(MapDestinationSearchResult.fromJson)
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      _knownPlaces = const <MapDestinationSearchResult>[];
    }
  }

  Future<void> _persist() async {
    final file = _file;
    if (file == null) return;
    final now = DateTime.now().toIso8601String();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode(<String, Object?>{
        'version': 1,
        'nearbyUpdatedAt': _nearbyUpdatedAt?.toIso8601String(),
        'nearbyOrigin': _nearbyOrigin == null
            ? null
            : <String, double>{
                'latitude': _nearbyOrigin!.latitude,
                'longitude': _nearbyOrigin!.longitude,
              },
        'places': _knownPlaces
            .map(
              (item) => <String, Object?>{
                ...item.toJson(),
                'cachedAt': now,
              },
            )
            .toList(growable: false),
      }),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }
}
