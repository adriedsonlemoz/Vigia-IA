import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/offline_poi_package.dart';
import 'package:vigiaia/models/route_explorer_models.dart';

void main() {
  test('pacote offline preserva area, nome, data e pontos', () {
    final now = DateTime.utc(2026, 9, 25, 4, 0);
    final package = OfflinePoiPackage.fromResults(
      id: 'cipo',
      name: 'Serra do Cipó',
      now: now,
      originLatitude: -19.34,
      originLongitude: -43.62,
      searchRadiusKm: 20,
      items: const <RouteExplorerResult>[
        RouteExplorerResult(
          id: 'fuel-1',
          category: RouteExplorerCategory.fuel,
          title: 'Posto teste',
          subtitle: 'Combustível',
          latitude: -19.30,
          longitude: -43.60,
          distanceMeters: 4200,
          source: 'offline',
          address: 'Rodovia MG-010, km 20',
          openingHours: '24/7',
          phone: '+55 31 3000-0000',
          website: 'https://example.com',
          amenities: <String>['Banheiro', 'Água potável'],
        ),
      ],
    );

    expect(package.contains(latitude: -19.34, longitude: -43.62), isTrue);
    expect(package.contains(latitude: -20.2, longitude: -43.62), isFalse);
    expect(package.itemCount, 1);

    final restored = OfflinePoiPackage.fromJson(package.toJson());
    expect(restored.id, 'cipo');
    expect(restored.name, 'Serra do Cipó');
    expect(restored.updatedAt, now);
    expect(restored.searchRadiusKm, 20);
    expect(restored.items.single.title, 'Posto teste');
    expect(restored.items.single.address, 'Rodovia MG-010, km 20');
    expect(restored.items.single.openingHours, '24/7');
    expect(restored.items.single.phone, '+55 31 3000-0000');
    expect(restored.items.single.website, 'https://example.com');
    expect(restored.items.single.amenities, contains('Água potável'));
  });

  test('bounds do pacote acompanham o raio pesquisado', () {
    final package = OfflinePoiPackage.fromResults(
      id: 'regiao',
      name: 'Região',
      now: DateTime.utc(2026, 9, 25),
      originLatitude: -19.9,
      originLongitude: -43.9,
      searchRadiusKm: 10,
      items: const <RouteExplorerResult>[],
    );

    expect(package.north, greaterThan(-19.9));
    expect(package.south, lessThan(-19.9));
    expect(package.east, greaterThan(-43.9));
    expect(package.west, lessThan(-43.9));
  });
}
