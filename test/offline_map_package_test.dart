import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/offline_map_package.dart';

void main() {
  test('pacote de mapa offline preserva metadados no JSON', () {
    final addedAt = DateTime.utc(2026, 9, 23, 12, 0);
    final updatedAt = DateTime.utc(2026, 9, 23, 12, 30);
    final expiresAt = DateTime.utc(2026, 9, 30, 12, 30);
    final item = OfflineMapPackage(
      id: 'mapa-1',
      name: 'Região de teste',
      path: '/tmp/regiao.mbtiles',
      sizeBytes: 42 * 1024 * 1024,
      addedAt: addedAt,
      updatedAt: updatedAt,
      sourceHost: 'maps.example',
      providerId: 'stadia-alidade-smooth',
      downloadKind: 'region',
      west: -45.8,
      south: -20.3,
      east: -45.5,
      north: -20.0,
      minZoom: 8,
      maxZoom: 16,
      expiresAt: expiresAt,
    );

    final restored = OfflineMapPackage.fromJson(item.toJson());

    expect(restored.id, item.id);
    expect(restored.name, item.name);
    expect(restored.path, item.path);
    expect(restored.sizeBytes, item.sizeBytes);
    expect(restored.addedAt, addedAt);
    expect(restored.sourceHost, 'maps.example');
    expect(restored.updatedAt, updatedAt);
    expect(restored.providerId, 'stadia-alidade-smooth');
    expect(restored.downloadKind, 'region');
    expect(restored.west, -45.8);
    expect(restored.south, -20.3);
    expect(restored.east, -45.5);
    expect(restored.north, -20.0);
    expect(restored.minZoom, 8);
    expect(restored.maxZoom, 16);
    expect(restored.expiresAt, expiresAt);
    expect(restored.contains(latitude: -20.15, longitude: -45.65), isTrue);
    expect(restored.contains(latitude: -21.0, longitude: -45.65), isFalse);
  });

  test('pacote legado sem bounds continua considerado utilizável', () {
    final item = OfflineMapPackage(
      id: 'legado',
      name: 'Legado',
      path: '/tmp/legado.mbtiles',
      sizeBytes: 1,
      addedAt: DateTime.utc(2026, 9, 23),
    );

    expect(item.hasBounds, isFalse);
    expect(item.contains(latitude: 0, longitude: 0), isTrue);
  });

  test('modos de mapa offline mantêm as três políticas esperadas', () {
    expect(
      OfflineMapMode.values.map((value) => value.name),
      containsAll(<String>['automatic', 'online', 'offline']),
    );
  });
}
