import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/nearby_place_query.dart';

void main() {
  test('consulta próxima usa bbox, regiões e não depende de texto digitado', () {
    final query = NearbyPlaceQuery.build(
      latitude: -20.17,
      longitude: -45.71,
      radiusKm: 65,
      maximumItems: 250,
      queryTimeoutSeconds: 16,
    );
    expect(query, contains('[timeout:16]'));
    expect(query, contains('nwr('));
    expect(query, contains('city|town|village|hamlet|isolated_dwelling'));
    expect(query, contains('out center 250;'));
    expect(query, isNot(contains('around:')));
    expect(query, isNot(contains('search')));
  });

  test('caixa geográfica respeita limites de latitude e longitude', () {
    final query = NearbyPlaceQuery.build(
      latitude: 89.9,
      longitude: 179.9,
      radiusKm: 65,
      maximumItems: 25,
      queryTimeoutSeconds: 12,
    );
    expect(query, contains(',90.00000,180.00000)'));
  });
}
