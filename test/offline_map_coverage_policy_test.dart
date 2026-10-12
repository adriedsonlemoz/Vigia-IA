import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/offline_map_package.dart';
import 'package:vigiaia/services/offline_map_coverage_policy.dart';

void main() {
  OfflineMapPackage sample({
    bool hasBounds = true,
    String? kind = 'region',
    int? maxZoom = 16,
  }) => OfflineMapPackage(
        id: 'local',
        name: 'Mapa salvo',
        path: '/tmp/local.mbtiles',
        sizeBytes: 100,
        addedAt: DateTime.utc(2026, 10, 12),
        west: hasBounds ? -46 : null,
        east: hasBounds ? -45 : null,
        south: hasBounds ? -21 : null,
        north: hasBounds ? -20 : null,
        minZoom: 8,
        maxZoom: maxZoom,
        downloadKind: kind,
      );

  test('sem pacote, a cobertura nao e afirmada', () {
    expect(
      OfflineMapCoveragePolicy.assess(
        package: null, latitude: -20.5, longitude: -45.5, zoom: 12),
      OfflineMapCoverageState.noPackage,
    );
  });
  test('MBTiles legado sem limites tem cobertura desconhecida', () {
    final status = OfflineMapCoveragePolicy.assess(
      package: sample(hasBounds: false),
      latitude: -20.5, longitude: -45.5, zoom: 12);
    expect(status, OfflineMapCoverageState.unknown);
    expect(OfflineMapCoveragePolicy.needsWarning(status), isTrue);
  });
  test('detecta posicao fora dos limites', () {
    expect(OfflineMapCoveragePolicy.assess(
      package: sample(), latitude: -25, longitude: -45.5, zoom: 12,
    ), OfflineMapCoverageState.outsideBounds);
  });
  test('detecta zoom sem tiles no pacote', () {
    expect(OfflineMapCoveragePolicy.assess(
      package: sample(), latitude: -20.5, longitude: -45.5, zoom: 18,
    ), OfflineMapCoverageState.outsideZoom);
  });
  test('o bounding box de corredor nao garante todo o retangulo', () {
    expect(OfflineMapCoveragePolicy.assess(
      package: sample(kind: 'route'), latitude: -20.5, longitude: -45.5, zoom: 12,
    ), OfflineMapCoverageState.corridorUnverified);
  });
  test('mesmo regioes com limites indicam somente cobertura possivel', () {
    final status = OfflineMapCoveragePolicy.assess(
      package: sample(), latitude: -20.5, longitude: -45.5, zoom: 12);
    expect(status, OfflineMapCoverageState.possible);
    expect(OfflineMapCoveragePolicy.needsWarning(status), isFalse);
  });
}
