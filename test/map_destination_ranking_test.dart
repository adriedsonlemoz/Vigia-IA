import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/map_destination_search.dart';
import 'package:vigiaia/services/map_destination_ranking.dart';

MapDestinationSearchResult place(
  String name, {
  required double distance,
  double lat = -20.0,
  double lon = -45.0,
  String id = 'osm:node:1',
  String subtitle = 'Minas Gerais',
  String source = 'online',
  MapDestinationKind kind = MapDestinationKind.village,
}) => MapDestinationSearchResult(
      id: id,
      title: name,
      subtitle: subtitle,
      latitude: lat,
      longitude: lon,
      distanceMeters: distance,
      kind: kind,
      source: source,
    );

void main() {
  test('nome próprio prevalece sobre Salvador no endereço', () {
    expect(
      MapDestinationRanking.canonicalTitle(<String, dynamic>{
        'name': 'Santo Antônio',
        'display_name': 'Santo Antônio, Salvador, Bahia, Brasil',
        'address': <String, String>{'city': 'Salvador'},
      }),
      'Santo Antônio',
    );
  });

  test('sem nome próprio usa primeiro termo, não cidade administrativa', () {
    expect(
      MapDestinationRanking.canonicalTitle(<String, dynamic>{
        'display_name': 'Rua Santo Antônio, Porto Alegre, RS',
        'address': <String, String>{'road': 'Rua Santo Antônio', 'city': 'Porto Alegre'},
      }),
      'Rua Santo Antônio',
    );
  });

  test('namedetails em português têm precedência sobre display e município', () {
    expect(
      MapDestinationRanking.canonicalTitle(<String, dynamic>{
        'display_name': 'Other name, city, Brazil',
        'namedetails': <String, String>{'name:pt': 'Santo Antônio'},
        'address': <String, String>{'city': 'Salvador'},
      }),
      'Santo Antônio',
    );
  });

  test('correspondência exata distante supera resultado local irrelevante', () {
    final values = MapDestinationRanking.ranked(<MapDestinationSearchResult>[
      place('Salvador', distance: 1000, subtitle: 'Bairro Santo Antônio'),
      place('Santo Antônio', distance: 1400000, lat: -10, id: 'osm:node:2'),
    ], 'santo Antônio');
    expect(values.first.title, 'Santo Antônio');
  });

  test('regionalidade desempata nomes equivalentes, sem excluir remoto', () {
    final values = MapDestinationRanking.ranked(<MapDestinationSearchResult>[
      place('Santo Antônio', distance: 1000000, lat: -11),
      place('Santo Antônio', distance: 3000, lat: -20.8, id: 'osm:node:2'),
    ], 'SANTO ANTONIO');
    expect(values.length, 2);
    expect(values.first.distanceMeters, 3000);
  });

  test('sufixo administrativo MG não substitui nome principal', () {
    final values = MapDestinationRanking.ranked(<MapDestinationSearchResult>[
      place('Iguatama', distance: 8000),
      place('Bairro', distance: 500,
          id: 'osm:node:2', subtitle: 'Iguatama, Minas Gerais'),
    ], 'Iguatama, MG');
    expect(values.first.title, 'Iguatama');
  });

  test('homônimos em cidades diferentes não são fundidos', () {
    final unique = MapDestinationRanking.deduplicate(<MapDestinationSearchResult>[
      place('Santo Antônio', distance: 1000, lat: -20.1, id: 'osm:node:10'),
      place('Santo Antônio', distance: 150000, lat: -19.0, id: 'osm:node:11'),
    ]);
    expect(unique.length, 2);
  });

  test('OSM de Nominatim e Overpass são identificados como um local', () {
    final unique = MapDestinationRanking.deduplicate(<MapDestinationSearchResult>[
      place('Iguatama', distance: 1200, id: 'osm:node:123', source: 'cache'),
      place('Iguatama', distance: 1200, lat: -20.00001,
          id: 'nominatim:N:123', source: 'online'),
    ]);
    expect(unique.length, 1);
    expect(unique.single.source, 'cache');
  });

  test('nome e coordenadas próximos são deduplicados sem OSM comum', () {
    final unique = MapDestinationRanking.deduplicate(<MapDestinationSearchResult>[
      place('Iguatama', distance: 100, id: 'osm:node:10', source: 'cache'),
      place('IGUATAMA', distance: 101, lat: -20.0002, lon: -45.0002,
          id: 'offline-local:1', source: 'offline'),
    ]);
    expect(unique.length, 1);
    expect(unique.single.source, 'offline');
  });

  test('cache legado não reapresenta Salvador para objeto Santo Antônio', () {
    final repaired = MapDestinationRanking.repairCachedTitle(
      place('Salvador', distance: 1000000,
          id: 'nominatim:way:9',
          subtitle: 'Santo Antônio, Salvador, Bahia, Brasil',
          source: 'cache'),
    );
    expect(repaired.title, 'Santo Antônio');
    expect(repaired.id, 'nominatim:way:9');
  });

  test('Nominatim online atualizado supera título legado em cache', () {
    final unique = MapDestinationRanking.deduplicate(<MapDestinationSearchResult>[
      place('Porto Alegre', distance: 10,
          id: 'nominatim:way:15', source: 'cache'),
      place('Rua Santo Antônio', distance: 10,
          id: 'nominatim:way:15', source: 'online'),
    ]);
    expect(unique.length, 1);
    expect(unique.single.title, 'Rua Santo Antônio');
  });

  test('topônimos acentuados são encontrados sem acento', () {
    expect(MapDestinationRanking.fold('São João do Pará'), 'sao joao do para');
    final ranked = MapDestinationRanking.ranked(<MapDestinationSearchResult>[
      place('São João do Pará', distance: 3000),
      place('São João', distance: 400, id: 'osm:node:2'),
    ], 'sao joao do para');
    expect(ranked.first.title, 'São João do Pará');
  });
}
