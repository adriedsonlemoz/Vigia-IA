import 'dart:convert';
import 'dart:io';

import 'data_usage_service.dart';

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
  RadioBrowserService({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;
  static const _hosts = <String>[
    'de1.api.radio-browser.info',
    'nl1.api.radio-browser.info',
    'at1.api.radio-browser.info',
    'all.api.radio-browser.info',
  ];

  void dispose() => _client.close(force: true);

  Future<List<RadioBrowserStation>> search({
    String query = '',
    bool brazilOnly = true,
    bool preferLowBitrate = false,
    int limit = 40,
  }) async {
    Object? lastError;
    for (final host in _hosts) {
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
            'VigiaIA/1.0.196 radio-browser');
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
        if (!preferLowBitrate) return decoded;
        final efficient = decoded
            .where((station) => station.bitrate == 0 || station.bitrate <= 96)
            .toList(growable: false);
        return efficient.isEmpty ? decoded : efficient;
      } catch (error) {
        lastError = error;
      }
    }
    throw HttpException(
      'Não foi possível consultar as rádios agora${lastError == null ? '.' : ': $lastError'}',
    );
  }

  static List<RadioBrowserStation> decodeStations(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! List) return const <RadioBrowserStation>[];
    final seen = <String>{};
    final stations = <RadioBrowserStation>[];
    for (final raw in decoded) {
      final station = RadioBrowserStation.fromJson(raw);
      if (station == null || !seen.add(station.streamUrl)) continue;
      stations.add(station);
    }
    return stations;
  }
}
