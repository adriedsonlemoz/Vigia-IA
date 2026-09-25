import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/route_explorer_models.dart';
import 'package:vigiaia/services/route_explorer_alert_policy.dart';

void main() {
  const policy = RouteExplorerAlertPolicy();
  final now = DateTime.utc(2026, 9, 25, 20);

  RouteExplorerResult poi({
    required String id,
    required RouteExplorerCategory category,
    required double distance,
    String source = 'online',
  }) =>
      RouteExplorerResult(
        id: id,
        category: category,
        title: id,
        subtitle: '',
        latitude: -19.9,
        longitude: -43.9,
        distanceMeters: distance,
        source: source,
      );

  test('respeita categorias preferidas ao escolher alerta', () {
    const settings = RouteExplorerSettings(
      categories: <RouteExplorerCategory>{RouteExplorerCategory.fuel},
      alertDistanceMeters: 5000,
    );
    final decision = policy.select(
      results: <RouteExplorerResult>[
        poi(
          id: 'oficina',
          category: RouteExplorerCategory.workshop,
          distance: 500,
        ),
        poi(
          id: 'posto',
          category: RouteExplorerCategory.fuel,
          distance: 1800,
        ),
      ],
      settings: settings,
      deliveredThresholds: <String, Set<int>>{},
      now: now,
    );

    expect(decision?.item.id, 'posto');
    expect(decision?.thresholdMeters, 5000);
  });

  test('entrada já perto usa marco final e consome marcos maiores', () {
    const settings = RouteExplorerSettings(alertDistanceMeters: 5000);
    final decision = policy.select(
      results: <RouteExplorerResult>[
        poi(
          id: 'agua',
          category: RouteExplorerCategory.water,
          distance: 850,
          source: 'offline',
        ),
      ],
      settings: settings,
      deliveredThresholds: <String, Set<int>>{},
      now: now,
    );

    expect(decision, isNotNull);
    expect(decision!.thresholdMeters, 1000);
    expect(decision.consumedThresholds, <int>{1000, 5000});
    expect(decision.item.source, 'offline');
  });

  test('cooldown global impede sequência excessiva de POIs', () {
    const settings = RouteExplorerSettings(alertDistanceMeters: 3000);
    final decision = policy.select(
      results: <RouteExplorerResult>[
        poi(
          id: 'camping',
          category: RouteExplorerCategory.camping,
          distance: 1200,
        ),
      ],
      settings: settings,
      deliveredThresholds: <String, Set<int>>{},
      now: now.add(const Duration(seconds: 30)),
      lastDeliveredAt: now,
    );

    expect(decision, isNull);
    expect(RouteExplorerAlertPolicy.minimumInterval, const Duration(minutes: 1));
  });
}
