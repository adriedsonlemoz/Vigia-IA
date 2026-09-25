import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/route_explorer_models.dart';
import 'package:vigiaia/services/map_poi_display_policy.dart';

RouteExplorerResult poi(
  String id,
  RouteExplorerCategory category,
  double latitude,
  double longitude, {
  double distance = 1000,
}) =>
    RouteExplorerResult(
      id: id,
      category: category,
      title: id,
      subtitle: '',
      latitude: latitude,
      longitude: longitude,
      distanceMeters: distance,
    );

void main() {
  test('agrupa POIs próximos quando o zoom está distante', () {
    final clusters = MapPoiDisplayPolicy.clusters(
      zoom: 12,
      items: <RouteExplorerResult>[
        poi('a', RouteExplorerCategory.fuel, -19.9200, -43.9400),
        poi('b', RouteExplorerCategory.restaurant, -19.9203, -43.9402),
        poi('c', RouteExplorerCategory.water, -19.9204, -43.9401),
      ],
    );

    expect(clusters.length, 1);
    expect(clusters.single.count, 3);
    expect(clusters.single.isCluster, isTrue);
  });

  test('POI selecionado fica individual mesmo dentro de um cluster', () {
    final clusters = MapPoiDisplayPolicy.clusters(
      zoom: 11,
      selectedId: 'b',
      items: <RouteExplorerResult>[
        poi('a', RouteExplorerCategory.riverBridge, -19.9200, -43.9400),
        poi('b', RouteExplorerCategory.water, -19.9201, -43.9401),
        poi('c', RouteExplorerCategory.riverBridge, -19.9202, -43.9402),
      ],
    );

    expect(
      clusters.any((cluster) => cluster.count == 1 && cluster.first.id == 'b'),
      isTrue,
    );
  });

  test('reduz rios e pontes agressivamente em visão regional', () {
    final items = <RouteExplorerResult>[
      for (var index = 0; index < 20; index++)
        poi(
          'river-$index',
          RouteExplorerCategory.riverBridge,
          -19.9 + (index * 0.01),
          -43.9,
          distance: index * 1000,
        ),
      poi('fuel', RouteExplorerCategory.fuel, -19.8, -43.8),
    ];

    final clusters = MapPoiDisplayPolicy.clusters(zoom: 9, items: items);
    final displayed = clusters.expand((cluster) => cluster.items).toList();

    expect(
      displayed.where((item) => item.category == RouteExplorerCategory.riverBridge),
      isEmpty,
    );
    expect(displayed.any((item) => item.id == 'fuel'), isTrue);
  });
}
