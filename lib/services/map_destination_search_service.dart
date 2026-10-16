import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import 'data_usage_service.dart';
import 'map_destination_ranking.dart';
import 'nearby_place_query.dart';

import '../models/map_destination_search.dart';
import '../models/map_route_point.dart';
import '../models/offline_map_package.dart';
import '../models/offline_poi_package.dart';
import '../models/route_explorer_models.dart';

class MapDestinationSearchService extends ChangeNotifier {
  MapDestinationSearchService._();

  static final MapDestinationSearchService instance =
      MapDestinationSearchService._();

  static const double nearbyRadiusKm = 90;
  static const double quickNearbyRadiusKm = 35;
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
  List<MapDestinationSearchResult> _savedPlaces =
      const <MapDestinationSearchResult>[];
  List<MapDestinationSearchResult> _recentPlaces =
      const <MapDestinationSearchResult>[];
  List<MapDestinationSearchResult> _suggestions =
      const <MapDestinationSearchResult>[];
  List<MapDestinationSearchResult> _results =
      const <MapDestinationSearchResult>[];
  DateTime? _nearbyUpdatedAt;
  LatLng? _nearbyOrigin;
  DateTime? _lastNominatimRequestAt;
  Future<void> _nominatimGate = Future<void>.value();
  final Map<String, ({DateTime at, List<MapDestinationSearchResult> items})>
      _queryCache = {};
  int _searchRevision = 0;
  DateTime? _nearbyRetryAfter;
  bool _nearbyLastFetchFailed = false;

  bool get loading => _suggestionsLoading || _searchLoading;
  bool get suggestionsLoading => _suggestionsLoading;
  bool get nearbyLastFetchFailed => _nearbyLastFetchFailed;
  bool get searchLoading => _searchLoading;
  String? get statusMessage => _searchStatusMessage ?? _suggestionsStatusMessage;
  String? get suggestionsStatusMessage => _suggestionsStatusMessage;
  String? get searchStatusMessage => _searchStatusMessage;
  List<MapDestinationSearchResult> get suggestions =>
      List<MapDestinationSearchResult>.unmodifiable(_suggestions);
  List<MapDestinationSearchResult> get results =>
      List<MapDestinationSearchResult>.unmodifiable(_results);
  List<MapDestinationSearchResult> get savedPlaces =>
      List<MapDestinationSearchResult>.unmodifiable(_savedPlaces);
  bool isRecentPlace(MapDestinationSearchResult item) =>
      _recentPlaces.any((place) => place.id == item.id);
  bool isSavedPlace(MapDestinationSearchResult item) =>
      _savedPlaces.any((place) => place.id == item.id);

  String resultSection(MapDestinationSearchResult item, String query) {
    final typed = _fold(query.split(',').first);
    final title = _fold(item.title);
    if (typed.isNotEmpty &&
        title.contains(typed)) {
      return 'Correspondências pelo nome';
    }
    if (isSavedPlace(item)) return 'Locais salvos';
    if (isRecentPlace(item)) return 'Recentes';
    return item.distanceMeters <= nearbyRadiusKm * 1000
        ? 'Na região'
        : 'Outros lugares';
  }


  /// Guarda até 20 destinos escolhidos, sem consultar o servidor a cada tecla.
  Future<void> rememberRecentPlace(MapDestinationSearchResult item) async {
    await initialize();
    _recentPlaces = <MapDestinationSearchResult>[
      item.copyWith(source: 'cache'),
      ..._recentPlaces.where((place) => place.id != item.id),
    ].take(20).toList(growable: false);
    _mergeKnownPlaces(<MapDestinationSearchResult>[item]);
    notifyListeners();
    await _persist();
  }

  Future<void> savePlace(MapDestinationSearchResult item) async {
    await initialize();
    _savedPlaces = <MapDestinationSearchResult>[
      item.copyWith(source: 'offline'),
      ..._savedPlaces.where((place) => place.id != item.id),
    ];
    notifyListeners();
    await _persist();
  }

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
    bool forceRefresh = false,
  }) async {
    await initialize();
    _suggestions = _buildLocalSuggestions(
      current: current,
      offlineMaps: offlineMaps,
      onlyDownloaded: !onlineAllowed,
    );
    notifyListeners();

    if (!onlineAllowed) {
      _suggestionsStatusMessage = 'Offline · cidades disponíveis somente nos dados salvos.';
      notifyListeners();
      return;
    }
    if (_nearbyRefreshInFlight) {
      _suggestionsStatusMessage = _suggestions.isEmpty
          ? 'Buscando cidades e comunidades próximas…'
          : 'Mostrando dados salvos · atualização em andamento.';
      notifyListeners();
      return;
    }
    if (!forceRefresh && !_needsNearbyRefresh(current)) {
      _suggestionsStatusMessage = 'Cidades e comunidades próximas salvas.';
      notifyListeners();
      return;
    }
    if (!forceRefresh && _nearbyRetryAfter != null &&
        DateTime.now().isBefore(_nearbyRetryAfter!)) {
      _suggestionsStatusMessage = _suggestions.isEmpty
          ? 'Serviço de localidades indisponível. Toque em Atualizar para tentar novamente.'
          : 'Exibindo localidades salvas. Toque em Atualizar para buscar novas.';
      notifyListeners();
      return;
    }

    _nearbyRefreshInFlight = true;
    _nearbyLastFetchFailed = false;
    _suggestionsStatusMessage = 'Buscando cidades e comunidades próximas…';
    _setSuggestionsLoading(true);
    try {
      // A janela anterior de 5 s encerrava a consulta antes de muitos
      // servidores Overpass responderem. A busca rápida inclui um espelho.
      var quick = const <MapDestinationSearchResult>[];
      var quickFailed = false;
      try {
        quick = await _fetchNearbyPlaces(
          current,
          radiusKm: quickNearbyRadiusKm,
          timeout: const Duration(seconds: 16),
          maximumItems: 180,
          allowMirror: true,
        );
      } catch (_) {
        quickFailed = true;
        // Uma falha na fase curta não deve impedir a busca regional.
      }
      var fetchedAny = quick.isNotEmpty;
      var expandedFailed = false;
      if (quick.isNotEmpty) {
        _mergeKnownPlaces(quick);
        _suggestions = _buildLocalSuggestions(
          current: current,
          offlineMaps: offlineMaps,
          onlyDownloaded: false,
        );
        _suggestionsStatusMessage = 'Localidades próximas encontradas.';
        notifyListeners();
      }
      // Não reter o indicador de carregamento durante a expansão regional.
      _setSuggestionsLoading(false);
      if (quick.isEmpty || _suggestions.length < maximumSuggestions) {
        _suggestionsStatusMessage = _suggestions.isEmpty
            ? 'Ampliando a busca regional…'
            : 'Localidades próximas prontas · ampliando a região…';
        notifyListeners();
        try {
          final expanded = await _fetchNearbyPlaces(
            current,
            radiusKm: nearbyRadiusKm,
            timeout: const Duration(seconds: 22),
            maximumItems: 220,
            allowMirror: true,
          );
          if (expanded.isNotEmpty) {
            fetchedAny = true;
            _mergeKnownPlaces(expanded);
            _suggestions = _buildLocalSuggestions(
              current: current,
              offlineMaps: offlineMaps,
              onlyDownloaded: false,
            );
          }
        } catch (_) {
          expandedFailed = true;
          // Não apagar resultados da fase curta por instabilidade da região.
        }
      }
      if (!fetchedAny) {
        // Dados antigos em memória NÃO validam uma consulta online vazia.
        _nearbyLastFetchFailed = quickFailed || expandedFailed;
        _nearbyRetryAfter = DateTime.now().add(const Duration(minutes: 2));
        _suggestionsStatusMessage = _suggestions.isNotEmpty
            ? 'Mostrando locais salvos. Toque em Atualizar para tentar novamente.'
            : expandedFailed
                ? 'Servidores de localidades indisponíveis. Toque em Atualizar.'
                : 'Nenhuma localidade recebida. Toque em Atualizar.';
      } else {
        _nearbyUpdatedAt = DateTime.now();
        _nearbyOrigin = LatLng(current.latitude, current.longitude);
        _nearbyRetryAfter = null;
        _suggestionsStatusMessage = 'Cidades e comunidades próximas prontas.';
        await _persist();
      }
      notifyListeners();
    } catch (_) {
      _nearbyLastFetchFailed = true;
      _nearbyRetryAfter = DateTime.now().add(const Duration(minutes: 2));
      _suggestionsStatusMessage = _suggestions.isEmpty
          ? 'Serviço de localidades indisponível. Toque em Atualizar para tentar novamente.'
          : 'Não foi possível atualizar. Mostrando localidades salvas.';
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
    _searchRevision++;
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
    _results = MapDestinationRanking.ranked(
      matches, text, limit: maximumSuggestions,
    );
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
    final revision = ++_searchRevision;
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
    _results = MapDestinationRanking.ranked(
      local, text, limit: maximumResults,
    );
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
      if (revision != _searchRevision) return;
      _results = MapDestinationRanking.ranked(
        <MapDestinationSearchResult>[...local, ...remote],
        text,
        limit: maximumResults,
      );
      _searchStatusMessage = _results.isEmpty
          ? 'Nenhum resultado encontrado.'
          : '${_results.length} resultado(s) · online + dados salvos.';
      await _persist();
    } on TimeoutException {
      if (revision != _searchRevision) return;
      _searchStatusMessage = local.isEmpty
          ? 'A pesquisa online demorou demais.'
          : 'Pesquisa online indisponível · mostrando dados salvos.';
    } on SocketException {
      if (revision != _searchRevision) return;
      _searchStatusMessage = local.isEmpty
          ? 'Sem internet e sem resultado offline para esta busca.'
          : 'Sem internet · mostrando dados salvos.';
    } catch (_) {
      if (revision != _searchRevision) return;
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
    final places = <MapDestinationSearchResult>[..._recentPlaces, ..._savedPlaces, ..._knownPlaces]
        .map(
          (item) => _withDistanceAndOfflineSource(
            item,
            current: current,
            offlineMaps: offlineMaps,
          ),
        )
        .where((item) => item.distanceMeters <= nearbyRadiusKm * 1000)
        .where((item) => !onlyDownloaded || item.storedLocally ||
            isRecentPlace(item))
        .where((item) => item.kind != MapDestinationKind.pointOfInterest)
        .toList(growable: true);
    final unique = MapDestinationRanking.deduplicate(places)
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return unique.take(maximumSuggestions).toList(growable: false);
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

    for (final place in <MapDestinationSearchResult>[..._recentPlaces, ..._savedPlaces, ..._knownPlaces]) {
      if (!_matches(needle, place.title, place.subtitle)) continue;
      final resolved = _withDistanceAndOfflineSource(
        place,
        current: current,
        offlineMaps: offlineMaps,
      );
      // Índice persistido, favoritos e recentes são pesquisáveis sem rede,
      // mesmo se o mapa-base dessa região ainda não foi baixado.
      if (!onlyDownloaded || resolved.storedLocally ||
          isRecentPlace(resolved)) {
        found.add(resolved);
      }
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

    return _dedupeAndSort(found);
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
    request.headers.set(HttpHeaders.userAgentHeader, 'VigiaIA/1.0.259');
    request.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
      charset: 'utf-8',
    );
    request.write('data=${Uri.encodeQueryComponent(query.toString())}');
    final response = await request.close().timeout(const Duration(seconds: 22));
    final body = await utf8.decoder.bind(response).join();
    DataUsageService.instance.record(
      DataUsageModule.nearby,
      received: utf8.encode(body).length,
    );
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
    request.headers.set(HttpHeaders.userAgentHeader, 'VigiaIA/1.0.259');
    request.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
      charset: 'utf-8',
    );
    request.write('data=${Uri.encodeQueryComponent(query)}');
    final response = await request.close().timeout(const Duration(seconds: 20));
    final body = await utf8.decoder.bind(response).join();
    DataUsageService.instance.record(
      DataUsageModule.nearby,
      received: utf8.encode(body).length,
    );
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
    required bool allowMirror,
  }) async {
    final query = NearbyPlaceQuery.build(
      latitude: current.latitude,
      longitude: current.longitude,
      radiusKm: radiusKm,
      maximumItems: maximumItems,
      queryTimeoutSeconds: timeout.inSeconds - 2,
    );
    // Instâncias públicas podem responder com 429/504 ou não responder.
    // Usar espelho apenas para a consulta inicial evita multiplicar cargas.
    final endpoints = <Uri>[
      Uri.parse('https://overpass-api.de/api/interpreter'),
      if (allowMirror)
        Uri.parse('https://overpass.private.coffee/api/interpreter'),
    ];
    Object? lastFailure;
    for (final endpoint in endpoints) {
      try {
        // O limite engloba conexão, resposta e leitura, não cada etapa
        // separadamente. Assim um servidor lento não prende o painel.
        final body = await _readNearbyResponse(endpoint, query).timeout(timeout);
        final decoded = jsonDecode(body);
        if (decoded is! Map || decoded['elements'] is! List) {
          throw const FormatException('Resposta Overpass inválida');
        }
        final elements = decoded['elements'] as List;
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
          final distance = _meters(
            current.latitude, current.longitude, lat, lon,
          );
          // A caixa de busca contém cantos além do círculo solicitado.
          if (distance > radiusKm * 1000) continue;
          final placeType = tags['place'];
          final state = tags['addr:state'] ?? tags['state'];
          final subtitleParts = <String>[
            MapDestinationKindX.fromOsmType(placeType).label,
            if (state != null && state.trim().isNotEmpty) state.trim(),
          ];
          results.add(MapDestinationSearchResult(
            id: 'osm:${item['type']}:${item['id']}',
            title: name,
            subtitle: subtitleParts.join(' · '),
            latitude: lat,
            longitude: lon,
            distanceMeters: distance,
            kind: MapDestinationKindX.fromOsmType(placeType),
            source: 'online',
          ));
        }
        return _dedupeAndSort(results);
      } catch (error) {
        lastFailure = error;
      }
    }
    throw StateError('Todas as instâncias Overpass falharam: $lastFailure');
  }

  Future<String> _readNearbyResponse(Uri endpoint, String query) async {
    final request = await _client.postUrl(endpoint);
    request.headers.set(HttpHeaders.userAgentHeader, 'VigiaIA/1.0.259');
    request.headers.contentType = ContentType(
      'application', 'x-www-form-urlencoded', charset: 'utf-8',
    );
    request.write('data=${Uri.encodeQueryComponent(query)}');
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    DataUsageService.instance.record(
      DataUsageModule.nearby,
      received: utf8.encode(body).length,
    );
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Overpass HTTP ${response.statusCode}');
    }
    return body;
  }

  Future<MapDestinationSearchResult> reverseLookup({
    required LatLng point,
    required MapRoutePoint? current,
    required bool onlineAllowed,
    required List<OfflinePoiPackage> offlinePoiPackages,
  }) async {
    await initialize();
    final localCandidates = <MapDestinationSearchResult>[
      ..._savedPlaces,
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
            distanceMeters: current == null ? 0 : _meters(
              current.latitude, current.longitude, poi.latitude, poi.longitude,
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
        distanceMeters: current == null ? 0 : _meters(
          current.latitude, current.longitude,
          nearest.latitude, nearest.longitude,
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
          'VigiaIA/1.0.259 map-reverse-search',
        );
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        final response = await request.close().timeout(const Duration(seconds: 8));
        final body = await utf8.decoder.bind(response).join();
        DataUsageService.instance.record(
          DataUsageModule.nearby,
          received: utf8.encode(body).length,
        );
    
        if (response.statusCode == HttpStatus.ok) {
          final decoded = jsonDecode(body);
          if (decoded is Map) {
            final item = decoded.cast<String, dynamic>();
            final displayName = item['display_name']?.toString().trim() ?? '';
            final title = MapDestinationRanking.canonicalTitle(item);
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
              distanceMeters: current == null ? 0 : _meters(
                current.latitude, current.longitude,
                point.latitude, point.longitude,
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
      distanceMeters: current == null ? 0 : _meters(
        current.latitude, current.longitude,
        point.latitude, point.longitude,
      ),
      kind: MapDestinationKind.place,
      source: onlineAllowed ? 'coordinate' : 'offline',
    );
  }

  Future<List<MapDestinationSearchResult>> _fetchNominatim(
    String query,
    MapRoutePoint current,
  ) async {
    final cacheKey = '${MapDestinationRanking.fold(query)}:'
        '${(current.latitude * 2).round()}:${(current.longitude * 2).round()}';
    final cached = _queryCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.at) < const Duration(hours: 1)) {
      return cached.items
          .map((item) => item.copyWith(distanceMeters: _meters(
              current.latitude, current.longitude,
              item.latitude, item.longitude)))
          .toList(growable: false);
    }
    await _respectNominatimRateLimit();
    // Caixa aproximada arredondada a 0,5 grau para reduzir precisão enviada.
    // bounded=0: preferência geográfica, sem bloquear lugares remotos.
    final approxLat = (current.latitude * 2).round() / 2;
    final approxLon = (current.longitude * 2).round() / 2;
    final regionalBox = approxLon.abs() < 170 && approxLat.abs() < 80
        ? <String, String>{
            'viewbox': '${approxLon - 2.5},${approxLat + 2.0},'
                '${approxLon + 2.5},${approxLat - 2.0}',
            'bounded': '0',
          }
        : const <String, String>{};
    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      <String, String>{
        'q': query,
        'format': 'jsonv2',
        'addressdetails': '1',
        'namedetails': '1',
        'limit': '20',
        'accept-language': 'pt-BR,pt,en',
        ...regionalBox,
      },
    );
    final request = await _client.getUrl(uri).timeout(const Duration(seconds: 8));
    request.headers.set(HttpHeaders.userAgentHeader, 'VigiaIA/1.0.259 map-search');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 15));
    final body = await utf8.decoder.bind(response).join();
    DataUsageService.instance.record(
      DataUsageModule.nearby,
      received: utf8.encode(body).length,
    );

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
      final type = item['type']?.toString();
      final category = item['category']?.toString();
      final title = MapDestinationRanking.canonicalTitle(item);
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
    final unique = _dedupeAndSort(results);
    // Cache pequeno e somente em memória para evitar buscas repetidas.
    if (_queryCache.length >= 24) {
      _queryCache.remove(_queryCache.keys.first);
    }
    _queryCache[cacheKey] = (at: DateTime.now(), items: unique);
    return unique;
  }

  /// Reserva uma janela antes de enviar qualquer busca/reversa ao Nominatim.
  /// A reserva é serializada mesmo se duas ações forem iniciadas juntas.
  Future<void> _respectNominatimRateLimit() async {
    final previous = _nominatimGate;
    final turn = Completer<void>();
    _nominatimGate = turn.future;
    try {
      await previous;
      final last = _lastNominatimRequestAt;
      if (last != null) {
        final wait = const Duration(milliseconds: 1100) -
            DateTime.now().difference(last);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      _lastNominatimRequestAt = DateTime.now();
    } finally {
      turn.complete();
    }
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

  String _fold(String value) => MapDestinationRanking.fold(value);

  List<MapDestinationSearchResult> _dedupeAndSort(
    Iterable<MapDestinationSearchResult> source,
  ) {
    final values = MapDestinationRanking.deduplicate(source)
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
    _knownPlaces = MapDestinationRanking.deduplicate(
      merged.values,
    ).take(600).toList(growable: false);
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
      // Índices anteriores podiam registrar uma consulta vazia como sucesso
      // e impedir novas buscas por três dias. Migrar sem apagar os locais.
      _nearbyUpdatedAt = map['version'] == 2 ? updatedAt : null;
      if (origin is Map) {
        final lat = (origin['latitude'] as num?)?.toDouble();
        final lon = (origin['longitude'] as num?)?.toDouble();
        if (lat != null && lon != null) _nearbyOrigin = LatLng(lat, lon);
      }
      final now = DateTime.now();
      final rawPlaces = (map['places'] as List?) ?? const <Object>[];
      _savedPlaces = ((map['savedPlaces'] as List?) ?? const <Object>[])
          .whereType<Map>()
          .map((item) => MapDestinationRanking.repairCachedTitle(
              MapDestinationSearchResult.fromJson(
                  item.cast<String, dynamic>())).copyWith(source: 'offline'))
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
      _recentPlaces = ((map['recentPlaces'] as List?) ?? const <Object>[])
          .whereType<Map>()
          .map((item) => MapDestinationRanking.repairCachedTitle(
              MapDestinationSearchResult.fromJson(
                  item.cast<String, dynamic>())))
          .where((item) => item.id.isNotEmpty)
          .take(20)
          .toList(growable: false);
      _knownPlaces = rawPlaces
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .where((item) {
            final cachedAt = DateTime.tryParse(item['cachedAt'] as String? ?? '');
            return cachedAt == null || now.difference(cachedAt) <= cacheRetention;
          })
          .map(MapDestinationSearchResult.fromJson)
          .map(MapDestinationRanking.repairCachedTitle)
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      _knownPlaces = const <MapDestinationSearchResult>[];
      _savedPlaces = const <MapDestinationSearchResult>[];
      _recentPlaces = const <MapDestinationSearchResult>[];
    }
  }

  Future<void> _persist() async {
    final file = _file;
    if (file == null) return;
    final now = DateTime.now().toIso8601String();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode(<String, Object?>{
        'version': 2,
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
        'savedPlaces': _savedPlaces.map((item) => item.toJson()).toList(),
        'recentPlaces': _recentPlaces.map((item) => item.toJson()).toList(),
      }),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }
}
