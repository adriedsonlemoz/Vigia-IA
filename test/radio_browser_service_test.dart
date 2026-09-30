import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/radio_browser_service.dart';

void main() {
  test('decoder preserva nome, localização e stream resolvido', () {
    final stations = RadioBrowserService.decodeStations('''
      [{
        "stationuuid": "abc",
        "name": "Rádio Teste",
        "url": "http://example.com/original",
        "url_resolved": "https://stream.example.com/live",
        "favicon": "https://example.com/logo.png",
        "country": "Brazil",
        "state": "Minas Gerais",
        "language": "portuguese",
        "codec": "MP3",
        "bitrate": 128,
        "votes": 42
      }]
    ''');

    expect(stations, hasLength(1));
    expect(stations.single.name, 'Rádio Teste');
    expect(stations.single.streamUrl, 'https://stream.example.com/live');
    expect(stations.single.location, 'Minas Gerais · Brazil');
    expect(stations.single.technicalSummary, contains('128 kb/s'));
  });

  test('decoder remove streams inválidos e URLs duplicadas', () {
    final stations = RadioBrowserService.decodeStations('''
      [
        {"name":"Sem URL","url_resolved":""},
        {"name":"Primeira","url_resolved":"https://radio.example/live"},
        {"name":"Duplicada","url_resolved":"https://radio.example/live"}
      ]
    ''');

    expect(
      stations.map((station) => station.name),
      orderedEquals(<String>['Primeira']),
    );
  });

  test('favorito mantém metadados úteis do catálogo', () {
    const station = RadioBrowserStation(
      id: 'id-1',
      name: 'Rádio Local',
      streamUrl: 'https://radio.example/live',
      faviconUrl: 'https://radio.example/logo.png',
      country: 'Brasil',
      state: 'Minas Gerais',
      language: 'Português',
      tags: 'notícias,música',
      codec: 'aac',
      bitrate: 96,
      votes: 12,
    );

    final restored = RadioBrowserStation.fromSavedMap(station.toSavedMap());
    expect(restored.name, station.name);
    expect(restored.location, station.location);
    expect(restored.codec, station.codec);
    expect(restored.bitrate, station.bitrate);
  });
}
