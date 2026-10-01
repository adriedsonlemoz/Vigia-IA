import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/radio_browser_service.dart';
import 'package:vigiaia/services/radio_catalog_cache.dart';
import 'package:vigiaia/services/radio_health_service.dart';
import 'package:vigiaia/services/radio_stream_resolver.dart';

RadioBrowserStation _station(String name, String url) => RadioBrowserStation(
      id: name,
      name: name,
      streamUrl: url,
      faviconUrl: '',
      country: 'Brasil',
      state: '',
      language: '',
      tags: '',
      codec: 'mp3',
      bitrate: 96,
      votes: 1,
    );

void main() {
  group('RadioStreamResolver', () {
    test('reconhece playlists e ignora HLS e streams diretos', () {
      expect(RadioStreamResolver.looksLikePlaylist('http://x.com/radio.pls'), isTrue);
      expect(RadioStreamResolver.looksLikePlaylist('https://x.com/lista.M3U'), isTrue);
      expect(RadioStreamResolver.looksLikePlaylist('https://x.com/live.m3u8'), isFalse);
      expect(RadioStreamResolver.looksLikePlaylist('https://x.com/stream'), isFalse);
    });

    test('extrai o stream de uma playlist PLS', () {
      const body = '[playlist]\nNumberOfEntries=1\nFile1=http://stream.example.com:8000/live\nTitle1=Radio\nLength1=-1\nversion=2\n';
      expect(RadioStreamResolver.parsePlaylist(body), 'http://stream.example.com:8000/live');
    });

    test('extrai o stream de uma playlist M3U com comentários e query string', () {
      const body = '#EXTM3U\n#EXTINF:-1,Radio\nhttps://s.example.com/live?token=abc\n';
      expect(RadioStreamResolver.parsePlaylist(body), 'https://s.example.com/live?token=abc');
    });

    test('devolve nulo quando não há URL válida', () {
      expect(RadioStreamResolver.parsePlaylist('#EXTM3U\nmusica.mp3\nfile://x\n'), isNull);
    });
  });

  group('RadioBrowserService', () {
    test('mergeHosts valida nomes, remove duplicados e mantém a reserva', () {
      final hosts = RadioBrowserService.mergeHosts(
        <String>['de1.api.radio-browser.info.', 'invalido.exemplo.com', 'de1.api.radio-browser.info', '10.0.0.1'],
        <String>['de1.api.radio-browser.info', 'nl1.api.radio-browser.info'],
      );
      expect(hosts, <String>['de1.api.radio-browser.info', 'nl1.api.radio-browser.info']);
    });

    test('decoder descarta estações reprovadas na verificação do catálogo', () {
      final stations = RadioBrowserService.decodeStations('''
        [
          {"name":"Ok","url_resolved":"https://a.example/live","lastcheckok":1},
          {"name":"Quebrada","url_resolved":"https://b.example/live","lastcheckok":0},
          {"name":"SSL","url_resolved":"https://c.example/live","lastcheckok":1,"ssl_error":1}
        ]
      ''');
      expect(stations.map((station) => station.name), <String>['Ok']);
    });

    test('rankStations leva estações instáveis para o fim sem mudar a ordem', () {
      final input = <RadioBrowserStation>[
        _station('A', 'https://a.example/live'),
        _station('B', 'https://b.example/live'),
        _station('C', 'https://c.example/live'),
      ];
      final ranked = RadioBrowserService.rankStations(
        input,
        isSuspect: (url) => url.contains('a.example'),
      );
      expect(ranked.map((station) => station.name), <String>['B', 'C', 'A']);
    });
  });

  group('Cache e saúde das estações', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('vigiaia_radio_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('cache guarda e devolve a última busca', () async {
      final cache = RadioCatalogCache(file: File('${dir.path}/cache.json'));
      final key = RadioCatalogCache.keyFor(query: ' Jovem ', brazilOnly: true);
      expect(key, 'br|jovem');
      expect(await cache.load(key), isNull);
      await cache.save(key, <RadioBrowserStation>[_station('A', 'https://a.example/live')]);
      final loaded = await cache.load(key);
      expect(loaded, isNotNull);
      expect(loaded!.single.name, 'A');
      expect(loaded.single.streamUrl, 'https://a.example/live');
    });

    test('estação vira instável após falhas e volta ao normal ao tocar', () async {
      final file = File('${dir.path}/health.json');
      final health = RadioHealthService(file: file);
      const url = 'https://a.example/live';
      await health.markFailed(url);
      expect(health.isSuspect(url), isFalse);
      await health.markFailed(url);
      expect(health.isSuspect(url), isTrue);

      final reopened = RadioHealthService(file: file);
      await reopened.load();
      expect(reopened.isSuspect(url), isTrue);

      await reopened.markWorking(url);
      expect(reopened.isSuspect(url), isFalse);
    });
  });
}
