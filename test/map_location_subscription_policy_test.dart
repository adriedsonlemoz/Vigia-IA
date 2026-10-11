import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/map_location_subscription_policy.dart';

void main() {
  test('sem uso ativo, mapa e ESP32 não mantêm GPS aberto', () {
    expect(MapLocationSubscriptionPolicy.keepStream(
      hasConsumer: false, recording: false, navigating: false,
      appForeground: true,
    ), isFalse);
    expect(MapLocationSubscriptionPolicy.needsOneShotFix(
      streamActive: false, keepStream: false,
    ), isTrue);
  });

  test('mapa visível mantém stream e evita chamada pontual duplicada', () {
    expect(MapLocationSubscriptionPolicy.keepStream(
      hasConsumer: true, recording: false, navigating: false,
      appForeground: true,
    ), isTrue);
    expect(MapLocationSubscriptionPolicy.needsOneShotFix(
      streamActive: false, keepStream: true,
    ), isFalse);
  });

  test('tela apagada suspende consumidor passivo mas mantém percurso', () {
    expect(MapLocationSubscriptionPolicy.keepStream(
      hasConsumer: true, recording: false, navigating: false,
      appForeground: false,
    ), isFalse);
    expect(MapLocationSubscriptionPolicy.keepStream(
      hasConsumer: false, recording: true, navigating: false,
      appForeground: false,
    ), isTrue);
    expect(MapLocationSubscriptionPolicy.keepStream(
      hasConsumer: false, recording: false, navigating: true,
      appForeground: false,
    ), isTrue);
  });

  test('sem stream, leitura pontual só em consulta isolada', () {
    expect(MapLocationSubscriptionPolicy.needsOneShotFix(
      streamActive: true, keepStream: true,
    ), isFalse);
    expect(MapLocationSubscriptionPolicy.needsOneShotFix(
      streamActive: true, keepStream: false,
    ), isFalse);
  });
}
