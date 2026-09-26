import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/map_destination_search.dart';

void main() {
  test('localidades OSM são classificadas sem transformar tudo em POI', () {
    expect(
      MapDestinationKindX.fromOsmType('city'),
      MapDestinationKind.city,
    );
    expect(
      MapDestinationKindX.fromOsmType('hamlet'),
      MapDestinationKind.community,
    );
    expect(
      MapDestinationKindX.fromOsmType('unknown'),
      MapDestinationKind.place,
    );
  });

  test('cache local só vira offline quando está coberto por mapa baixado', () {
    const item = MapDestinationSearchResult(
      id: 'osm:node:1',
      title: 'Comunidade Teste',
      subtitle: 'Comunidade',
      latitude: -20,
      longitude: -44,
      distanceMeters: 12000,
      kind: MapDestinationKind.community,
      source: 'cache',
    );

    expect(item.storedLocally, isTrue);
    expect(item.offline, isFalse);
    final restored = MapDestinationSearchResult.fromJson(item.toJson());
    expect(restored.title, item.title);
    expect(restored.kind, MapDestinationKind.community);
    expect(restored.storedLocally, isTrue);
    expect(restored.offline, isFalse);
    expect(restored.copyWith(source: 'offline').offline, isTrue);
  });
}
