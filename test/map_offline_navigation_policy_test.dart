import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/map_offline_navigation_policy.dart';

void main() {
  test('falha offline preserva a rota conhecida', () {
    final decision = MapOfflineNavigationPolicy.routeFailure(
      hasKnownRoute: true,
      networkOffline: true,
      recalculation: true,
    );
    expect(decision.keepKnownRoute, isTrue);
    expect(decision.message, contains('última rota conhecida'));
  });

  test('sem rota conhecida nao inventa geometria viaria', () {
    final decision = MapOfflineNavigationPolicy.routeFailure(
      hasKnownRoute: false,
      networkOffline: true,
      recalculation: false,
    );
    expect(decision.keepKnownRoute, isFalse);
    expect(decision.message, contains('direção do destino'));
  });
}
