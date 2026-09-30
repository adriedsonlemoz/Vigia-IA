import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/route_explorer_models.dart';
import 'package:vigiaia/services/route_explorer_poi_catalog.dart';

void main() {
  test('catálogo reconhece POIs de natureza e cicloviagem', () {
    expect(
      RouteExplorerPoiCatalog.resolveCategory(
        const <String, String>{'tourism': 'camp_site'},
      ),
      RouteExplorerCategory.camping,
    );
    expect(
      RouteExplorerPoiCatalog.resolveCategory(
        const <String, String>{'tourism': 'viewpoint'},
      ),
      RouteExplorerCategory.viewpoint,
    );
    expect(
      RouteExplorerPoiCatalog.resolveCategory(
        const <String, String>{'natural': 'waterfall'},
      ),
      RouteExplorerCategory.waterfall,
    );
    expect(
      RouteExplorerPoiCatalog.resolveCategory(
        const <String, String>{'shop': 'supermarket'},
      ),
      RouteExplorerCategory.market,
    );
    expect(
      RouteExplorerPoiCatalog.resolveCategory(
        const <String, String>{'shop': 'bicycle'},
      ),
      RouteExplorerCategory.workshop,
    );
  });

  test('metadados preservam informações úteis publicadas pelo POI', () {
    final metadata = RouteExplorerPoiCatalog.metadataFor(
      const <String, String>{
        'tourism': 'camp_site',
        'name': 'Camping do Vale',
        'addr:street': 'Estrada do Vale',
        'addr:housenumber': '12',
        'addr:city': 'Santana',
        'opening_hours': '24/7',
        'contact:phone': '+55 31 99999-0000',
        'website': 'https://example.com',
        'operator': 'Vale Camping',
        'drinking_water': 'yes',
        'toilets': 'yes',
        'shower': 'yes',
        'fee': 'yes',
      },
    );

    expect(metadata, isNotNull);
    final resolved = metadata!;
    expect(resolved.category, RouteExplorerCategory.camping);
    expect(resolved.title, 'Camping do Vale');
    expect(resolved.address, 'Estrada do Vale, 12 · Santana');
    expect(resolved.openingHours, '24/7');
    expect(resolved.phone, '+55 31 99999-0000');
    expect(resolved.website, 'https://example.com');
    expect(resolved.operatorName, 'Vale Camping');
    expect(
      resolved.amenities,
      containsAll(<String>['Água potável', 'Banheiro', 'Chuveiro', 'Pago']),
    );
  });

  test('configuração antiga recebe novas categorias uma única vez', () {
    final migrated = RouteExplorerSettings.fromJson(
      <String, dynamic>{
        'radiusKm': 20,
        'categories': <String>['fuel', 'water'],
        'poiCatalogVersion': 1,
      },
    );

    expect(
      migrated.categories,
      containsAll(<RouteExplorerCategory>[
        RouteExplorerCategory.fuel,
        RouteExplorerCategory.water,
        RouteExplorerCategory.camping,
        RouteExplorerCategory.viewpoint,
        RouteExplorerCategory.waterfall,
        RouteExplorerCategory.market,
      ]),
    );
    expect(
      migrated.poiCatalogVersion,
      RouteExplorerSettings.currentPoiCatalogVersion,
    );

    final saved = migrated.toJson();
    final userDisabledNature = Map<String, dynamic>.from(saved)
      ..['categories'] = <String>['fuel', 'water']
      ..['poiCatalogVersion'] = RouteExplorerSettings.currentPoiCatalogVersion;
    final restored = RouteExplorerSettings.fromJson(userDisabledNature);
    expect(restored.categories, isNot(contains(RouteExplorerCategory.camping)));
  });
}
