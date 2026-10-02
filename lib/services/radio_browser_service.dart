import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'data_usage_service.dart';
import 'radio_catalog_cache.dart';

class RadioBrowserStation {
  const RadioBrowserStation({
    required this.id,
    required this.name,
    required this.streamUrl,
    required this.faviconUrl,
    required this.country,
    required this.state,
    required this.language,
    required this.tags,
    required this.codec,
    required this.bitrate,
    required this.votes,
    this.lastCheckOk = true,
    this.sslError = false,
  });

  final String id;
  final String name;
  final String streamUrl;
  final String faviconUrl;
  final String country;
  final String state;
  final String language;
  final String tags;
  final String codec;
  final int bitrate;
  final int votes;

  /// Resultado da última verificação de saúde feita pelo catálogo.
  final bool lastCheckOk;

  /// O catálogo detectou erro de certificado no stream HTTPS.
  final bool sslError;

  bool get isHttps => streamUrl.toLowerCase().startsWith('https://');

  String get location {
    final parts = <String>[
      if (state.trim().isNotEmpty) state.trim(),
      if (country.trim().isNotEmpty) country.trim(),
    ];
    return parts.isEmpty ? 'Localidade não informada' : parts.join(' · ');
  }

  String get technicalSummary {
    final parts = <String>[
      if (codec.trim().isNotEmpty) codec.trim().toUpperCase(),
      if (bitrate > 0) '$bitrate kb/s',
      if (language.trim().isNotEmpty) language.trim(),
    ];
    return parts.isEmpty ? 'Stream ao vivo' : parts.join(' · ');
  }

  Map<String, String> toSavedMap() => <String, String>{
        'id': id,
        'name': name,
        'url': streamUrl,
        'favicon': faviconUrl,
        'country': country,
        'state': state,
        'language': language,
        'tags': tags,
        'codec': codec,
        'bitrate': bitrate.toString(),
      };

  static RadioBrowserStation? fromJson(Object? raw) {
    if (raw is! Map) return null;
    String value(String key) => raw[key]?.toString().trim() ?? '';
    final name = value('name');
    final streamUrl = value('url_resolved').isNotEmpty
        ? value('url_resolved')
        : value('url');
    final uri = Uri.tryParse(streamUrl);
    if (name.isEmpty || uri == null ||
        !<String>{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty) {
      return null;
    }
    return RadioBrowserStation(
      id: value('stationuuid'),
      name: name,
      streamUrl: uri.toString(),
      faviconUrl: value('favicon'),
      country: value('country'),
      state: value('state'),
      language: value('language'),
      tags: value('tags'),
      codec: value('codec'),
      bitrate: int.tryParse(value('bitrate')) ?? 0,
      votes: int.tryParse(value('votes')) ?? 0,
      lastCheckOk: value('lastcheckok') != '0',
      sslError: value('ssl_error') == '1',
    );
  }

  static RadioBrowserStation fromSavedMap(Map<String, String> raw) =>
      RadioBrowserStation(
        id: raw['id'] ?? '',
        name: raw['name'] ?? 'Estação',
        streamUrl: raw['url'] ?? '',
        faviconUrl: raw['favicon'] ?? '',
        country: raw['country'] ?? '',
        state: raw['state'] ?? '',
        language: raw['language'] ?? '',
        tags: raw['tags'] ?? '',
        codec: raw['codec'] ?? '',
        bitrate: int.tryParse(raw['bitrate'] ?? '') ?? 0,
        votes: 0,
      );
}

class RadioBrowserService {
  RadioBrowserService({
    HttpClient? client,
    Future<List<String>> Function()? hostResolver,
    RadioCatalogCache? cache,
  })  : _client = client ?? HttpClient(),
        _hostResolver = hostResolver ?? discoverHosts,
        _cache = cache ?? RadioCatalogCache();

  final HttpClient _client;
  final Future<List<String>> Function() _hostResolver;
  final RadioCatalogCache _cache;
  bool _lastSearchFromCache = false;

  /// Servidores conhecidos, usados só como reserva quando a descoberta por DNS falha.
  static const _fallbackHosts = <String>[
    'de1.api.radio-browser.info',
    'nl1.api.radio-browser.info',
    'at1.api.radio-browser.info',
    'all.api.radio-browser.info',
  ];
  static const _maxHostsPerSearch = 4;
  static List<String>? _discoveredHosts;
  static DateTime? _discoveredAt;

  /// `true` quando a última busca precisou usar o cache local.
  bool get lastSearchFromCache => _lastSearchFromCache;

  void dispose() => _client.close(force: true);

  /// Descobre os servidores do Radio Browser por DNS (como recomenda a
  /// documentação do catálogo) e devolve a lista em ordem aleatória, seguida
  /// da lista de reserva. O resultado é reaproveitado por uma hora.
  static Future<List<String>> discoverHosts() async {
    final cached = _discoveredHosts;
    final at = _discoveredAt;
    if (cached != null &&
        at != null &&
        DateTime.now().difference(at) < const Duration(hours: 1)) {
      return cached;
    }
    final discovered = <String>[];
    try {
      final addresses = await InternetAddress.lookup('all.api.radio-browser.info')
          .timeout(const Duration(seconds: 5));
      for (final address in addresses) {
        try {
          final reverse =
              await address.reverse().timeout(const Duration(seconds: 3));
          discovered.add(reverse.host);
        } catch (_) {
          continue;
        }
      }
    } catch (_) {
      // Sem DNS: segue apenas com a lista de reserva.
    }
    final merged = mergeHosts(discovered, _fallbackHosts);
    _discoveredHosts = merged;
    _discoveredAt = DateTime.now();
    return merged;
  }

  /// Valida os nomes descobertos, embaralha e acrescenta a lista de reserva.
  static List<String> mergeHosts(
    List<String> discovered,
    List<String> fallback, {
    Random? random,
  }) {
    final valid = <String>{};
    for (final raw in discovered) {
      final name = raw.trim().toLowerCase().replaceAll(RegExp(r'\.$'), '');
      if (name.endsWith('.radio-browser.info') &&
          name != 'all.api.radio-browser.info') {
        valid.add(name);
      }
    }
    final shuffled = valid.toList()..shuffle(random);
    return <String>[
      ...shuffled,
      ...fallback.where((host) => !valid.contains(host)),
    ];
  }

  Future<List<String>> _safeHosts() async {
    try {
      final hosts = await _hostResolver();
      if (hosts.isNotEmpty) return hosts;
    } catch (_) {
      // Usa a lista de reserva.
    }
    return _fallbackHosts;
  }

  Future<List<RadioBrowserStation>> search({
    String query = '',
    bool brazilOnly = true,
    bool preferLowBitrate = false,
    int limit = 40,
  }) async {
    final cacheKey =
        RadioCatalogCache.keyFor(query: query, brazilOnly: brazilOnly);
    Object? lastError;
    final hosts = (await _safeHosts()).take(_maxHostsPerSearch);
    for (final host in hosts) {
      try {
        final parameters = <String, String>{
          if (query.trim().isNotEmpty) 'name': query.trim(),
          if (brazilOnly) 'countrycode': 'BR',
          'hidebroken': 'true',
          'order': query.trim().isEmpty ? 'votes' : 'clickcount',
          'reverse': 'true',
          'limit': limit.clamp(1, 100).toString(),
        };
        final uri = Uri.https(host, '/json/stations/search', parameters);
        final request = await _client.getUrl(uri)
            .timeout(const Duration(seconds: 10));
        request.headers.set(HttpHeaders.userAgentHeader,
            'VigiaIA/1.0.206 radio-browser');
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        final response = await request.close()
            .timeout(const Duration(seconds: 12));
        if (response.statusCode != HttpStatus.ok) {
          await response.drain<void>();
          throw HttpException('Catálogo respondeu ${response.statusCode}.');
        }
        final text = await utf8.decoder.bind(response).join();
        DataUsageService.instance.record(
          DataUsageModule.radio,
          received: utf8.encode(text).length,
        );
        final decoded = decodeStations(text);
        _lastSearchFromCache = false;
        unawaited(_cache.save(cacheKey, decoded));
        return _applyBitratePreference(decoded, preferLowBitrate);
      } catch (error) {
        lastError = error;
      }
    }
    final cached = await _cache.load(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      _lastSearchFromCache = true;
      return _applyBitratePreference(cached, preferLowBitrate);
    }
    throw HttpException(
      'Não foi possível consultar as rádios agora${lastError == null ? '.' : ': $lastError'}',
    );
  }

  /// Informa ao catálogo que a estação foi tocada (contagem de cliques). É
  /// opcional e nunca atrapalha a reprodução.
  Future<void> registerClick(RadioBrowserStation station) async {
    final id = station.id.trim();
    if (id.isEmpty) return;
    try {
      final hosts = await _safeHosts();
      final uri = Uri.https(hosts.first, '/json/url/$id');
      final request =
          await _client.getUrl(uri).timeout(const Duration(seconds: 6));
      request.headers.set(HttpHeaders.userAgentHeader,
          'VigiaIA/1.0.206 radio-browser');
      final response = await request.close().timeout(const Duration(seconds: 8));
      await response.drain<void>();
    } catch (_) {
      // Falhas aqui não afetam a reprodução.
    }
  }

  static List<RadioBrowserStation> _applyBitratePreference(
    List<RadioBrowserStation> stations,
    bool preferLowBitrate,
  ) {
    if (!preferLowBitrate) return stations;
    final efficient = stations
        .where((station) => station.bitrate == 0 || station.bitrate <= 96)
        .toList(growable: false);
    return efficient.isEmpty ? stations : efficient;
  }

  /// Mantém a ordem do catálogo, mas leva as estações instáveis para o fim.
  static List<RadioBrowserStation> rankStations(
    List<RadioBrowserStation> stations, {
    bool Function(String url)? isSuspect,
  }) {
    if (isSuspect == null) return stations;
    final healthy = <RadioBrowserStation>[];
    final suspect = <RadioBrowserStation>[];
    for (final station in stations) {
      if (isSuspect(station.streamUrl)) {
        suspect.add(station);
      } else {
        healthy.add(station);
      }
    }
    return <RadioBrowserStation>[...healthy, ...suspect];
  }

  static List<RadioBrowserStation> decodeStations(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! List) return const <RadioBrowserStation>[];
    final seen = <String>{};
    final stations = <RadioBrowserStation>[];
    for (final raw in decoded) {
      final station = RadioBrowserStation.fromJson(raw);
      if (station == null) continue;
      if (!station.lastCheckOk || (station.sslError && station.isHttps)) continue;
      if (!seen.add(station.streamUrl)) continue;
      stations.add(station);
    }
    return stations;
  }
}
