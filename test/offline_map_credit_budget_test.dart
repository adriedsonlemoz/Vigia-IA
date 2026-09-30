import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/offline_map_service.dart';

void main() {
  test('tile raster padrao usa um credito por tile', () {
    expect(OfflineMapService.stadiaRasterCreditsPerTile, 1);
    expect(OfflineMapService.creditsForRasterTiles(8420), 8420);
    expect(OfflineMapService.creditsForRasterTiles(-1), 0);
  });

  test('estimativa de mapa expoe creditos junto dos tiles', () {
    const estimate = OfflineMapDownloadEstimate(
      tiles: 4500,
      bytes: 4500 * 24 * 1024,
    );

    expect(estimate.credits, 4500);
  });

  test('referencia do plano gratuito fica separada do limite local', () {
    expect(OfflineMapService.stadiaFreePlanReferenceCredits, 200000);
  });
}
