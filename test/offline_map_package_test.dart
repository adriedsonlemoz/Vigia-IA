import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/offline_map_package.dart';

void main() {
  test('pacote de mapa offline preserva metadados no JSON', () {
    final addedAt = DateTime.utc(2026, 9, 23, 12, 0);
    final item = OfflineMapPackage(
      id: 'mapa-1',
      name: 'Região de teste',
      path: '/tmp/regiao.mbtiles',
      sizeBytes: 42 * 1024 * 1024,
      addedAt: addedAt,
      sourceHost: 'maps.example',
    );

    final restored = OfflineMapPackage.fromJson(item.toJson());

    expect(restored.id, item.id);
    expect(restored.name, item.name);
    expect(restored.path, item.path);
    expect(restored.sizeBytes, item.sizeBytes);
    expect(restored.addedAt, addedAt);
    expect(restored.sourceHost, 'maps.example');
  });

  test('modos de mapa offline mantêm as três políticas esperadas', () {
    expect(
      OfflineMapMode.values.map((value) => value.name),
      containsAll(<String>['automatic', 'online', 'offline']),
    );
  });
}
