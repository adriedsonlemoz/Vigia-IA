import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/radio_browser_service.dart';
import 'package:vigiaia/services/radio_recent_history.dart';

RadioBrowserStation station(int id) => RadioBrowserStation(
  id: '$id',
  name: 'Estação $id',
  streamUrl: 'https://radio.example.org/$id',
  faviconUrl: '',
  country: 'Brasil',
  state: 'MG',
  language: 'portuguese',
  tags: 'pop',
  codec: 'aac',
  bitrate: 96,
  votes: 0,
);

void main() {
  test('histórico persiste, deduplica e respeita 20 estações', () async {
    final temp = await Directory.systemTemp.createTemp('vigia-radio-recents-');
    try {
      final file = File('${temp.path}/recents.json');
      final history = RadioRecentHistory(file: file);
      for (var i = 0; i < 24; i++) {
        await history.record(station(i));
      }
      expect((await history.load()).length, 20);
      expect((await history.load()).first.station.name, 'Estação 23');
      await history.record(station(5));
      final persisted = await RadioRecentHistory(file: file).load();
      expect(persisted.length, 20);
      expect(persisted.first.station.streamUrl, station(5).streamUrl);
      expect(persisted.where((e) => e.station.streamUrl == station(5).streamUrl).length, 1);
      await history.remove(station(5).streamUrl);
      expect((await history.load()).any((e) => e.station.streamUrl == station(5).streamUrl), isFalse);
      await history.clear();
      expect(await history.load(), isEmpty);
    } finally {
      await temp.delete(recursive: true);
    }
  });
}
