import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/mcrp_saved_cameras_store.dart';

void main() {
  late Directory directory;
  late McrpSavedCamerasStore store;
  const token = '0123456789abcdef0123456789abcdef';
  String url(int ip) => 'http://192.168.1.$ip:8765/live/$token';

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('vigia-saved-cameras-');
    store = McrpSavedCamerasStore(directoryProvider: () async => directory);
  });
  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('salva apenas quando solicitado e recupera após reiniciar', () async {
    expect(await store.load(), isEmpty);
    await store.save(name: 'Câmera traseira', liveUrl: url(42));
    final loaded = await McrpSavedCamerasStore(
      directoryProvider: () async => directory,
    ).load();
    expect(loaded.single.name, 'Câmera traseira');
    expect(loaded.single.liveUrl, url(42));
    expect(loaded.single.networkAddress, '192.168.1.42:8765');
    // O app não usa SharedPreferences ou diretórios públicos para armazenar token.
    expect(File('${directory.path}/${McrpSavedCamerasStore.fileName}').existsSync(), isTrue);
  });

  test('deduplica pelo QR, atualiza nome e mantém mais recente primeiro', () async {
    await store.save(name: 'Primeira', liveUrl: url(42));
    await store.save(name: 'Segunda', liveUrl: url(43));
    final cameras = await store.save(name: 'Renomeada', liveUrl: url(42));
    expect(cameras.length, 2);
    expect(cameras.map((camera) => camera.name).toList(), ['Renomeada', 'Segunda']);
  });

  test('remove somente o cadastro solicitado sem afetar as demais', () async {
    await store.save(name: 'A', liveUrl: url(42));
    await store.save(name: 'B', liveUrl: url(43));
    final cameras = await store.remove(url(42));
    expect(cameras.single.name, 'B');
    expect((await store.load()).single.liveUrl, url(43));
  });

  test('recusa URL externa, token inválido e nomes vazios', () async {
    expect(() => store.save(name: 'Externa',
      liveUrl: 'https://example.com/live/$token'), throwsFormatException);
    expect(() => store.save(name: '   ', liveUrl: url(42)), throwsFormatException);
    expect(() => store.save(name: 'A\nB', liveUrl: url(42)), throwsFormatException);
    expect(await store.load(), isEmpty);
  });

  test('descarta registros manipulados com URLs públicas ou inválidas', () async {
    final file = File('${directory.path}/${McrpSavedCamerasStore.fileName}');
    await file.writeAsString(jsonEncode([
      {'name': 'Suspeito', 'url': 'http://8.8.8.8:8765/live/$token'},
      {'name': 'OK', 'url': url(42)},
      {'name': 'Duplicado', 'url': url(42)},
      {'name': 'Incompleto', 'url': 'http://192.168.1.15/'},
    ]));
    final cameras = await store.load();
    expect(cameras.length, 1);
    expect(cameras.single.name, 'OK');
  });

  test('limita o total de cadastros a vinte', () async {
    for (var ip = 1; ip <= 25; ip++) {
      await store.save(name: 'Celular $ip', liveUrl: url(ip));
    }
    expect((await store.load()).length, McrpSavedCamerasStore.maximumCameras);
    expect((await store.load()).first.name, 'Celular 25');
    expect((await store.load()).last.name, 'Celular 6');
  });
}
