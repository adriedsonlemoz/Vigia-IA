import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/route_explorer_models.dart';
import 'package:vigiaia/services/route_explorer_poi_provenance.dart';
import 'package:vigiaia/services/route_explorer_poi_catalog.dart';

void main() {
  const poi = RouteExplorerResult(
    id: 'node-77-fuel',
    category: RouteExplorerCategory.fuel,
    title: 'Posto sem nome',
    subtitle: 'Combustível',
    latitude: -20,
    longitude: -45,
    distanceMeters: 600,
  );
  final now = DateTime.utc(2026, 10, 12, 12);

  test('POI sem data não deve ser mostrado como consulta recente', () {
    expect(RouteExplorerPoiProvenance.ageLabel(poi, now: now),
        'Data da consulta desconhecida');
  });
  test('consulta há 2 dias é rotulada com idade real', () {
    final dated = RouteExplorerResult(
      id: poi.id, category: poi.category, title: poi.title,
      subtitle: poi.subtitle, latitude: poi.latitude,
      longitude: poi.longitude, distanceMeters: poi.distanceMeters,
      fetchedAt: now.subtract(const Duration(days: 2)),
    );
    expect(RouteExplorerPoiProvenance.ageLabel(dated, now: now),
        'Consultado há 2 dias');
    final cached = dated.copyWith(source: 'cache');
    expect(RouteExplorerPoiProvenance.sourceLabel(cached), 'Cache local (OSM)');
    expect(cached.fetchedAt, dated.fetchedAt);
    final recovered = RouteExplorerResult.fromJson(cached.toJson());
    expect(recovered.fetchedAt, dated.fetchedAt);
    expect(recovered.source, 'cache');
  });
  test('offline não se transforma em serviço verificado', () {
    expect(RouteExplorerPoiProvenance.sourceLabel(poi.copyWith(source: 'offline')),
        'Pacote offline');
    expect(RouteExplorerPoiProvenance.serviceDisclaimer,
        contains('não foram verificados em tempo real'));
  });
  test('POI sem name usa identificação explícita, não título próximo', () {
    final metadata = RouteExplorerPoiCatalog.metadataFor(
        const <String, String>{'amenity': 'fuel'});
    expect(metadata, isNotNull);
    expect(metadata!.title, 'Posto sem nome');
  });
}
