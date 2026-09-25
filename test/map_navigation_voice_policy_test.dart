import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/map_navigation_guidance.dart';
import 'package:vigiaia/services/map_navigation_voice_policy.dart';

void main() {
  final now = DateTime.utc(2026, 9, 25, 20);

  MapNavigationProgress progress({
    String? next = 'Vire à esquerda',
    double? distance = 750,
    bool arrived = false,
  }) =>
      MapNavigationProgress(
        currentInstruction: 'Siga em frente',
        nextInstruction: next,
        distanceToNextManeuverMeters: distance,
        remainingDistanceMeters: 2500,
        remainingDurationSeconds: 600,
        progressFraction: 0.2,
        distanceFromRouteMeters: 4,
        offRoute: false,
        arrived: arrived,
      );

  test('fala próxima manobra com distância sem repetir o mesmo marco', () {
    final policy = MapNavigationVoicePolicy();
    final first = policy.evaluate(progress(), now: now);
    final duplicate = policy.evaluate(
      progress(distance: 720),
      now: now.add(const Duration(seconds: 3)),
    );
    final closer = policy.evaluate(
      progress(distance: 480),
      now: now.add(const Duration(seconds: 12)),
    );

    expect(first?.text, 'Em 750 metros, Vire à esquerda.');
    expect(duplicate, isNull);
    expect(closer?.text, 'Em 500 metros, Vire à esquerda.');
  });

  test('marco urgente de 80 m não fica preso ao intervalo normal', () {
    final policy = MapNavigationVoicePolicy();
    policy.evaluate(progress(distance: 180), now: now);
    final urgent = policy.evaluate(
      progress(distance: 70),
      now: now.add(const Duration(seconds: 2)),
    );

    expect(urgent, isNotNull);
    expect(urgent!.text, 'Em 70 metros, Vire à esquerda.');
    expect(urgent.highPriority, isTrue);
  });

  test('chegada é anunciada uma única vez', () {
    final policy = MapNavigationVoicePolicy();
    final first = policy.evaluate(
      progress(next: null, distance: null, arrived: true),
      now: now,
    );
    final second = policy.evaluate(
      progress(next: null, distance: null, arrived: true),
      now: now.add(const Duration(seconds: 5)),
    );

    expect(first?.text, 'Você chegou ao destino.');
    expect(first?.highPriority, isTrue);
    expect(second, isNull);
  });

  test('distância em quilômetros usa fala natural em português', () {
    expect(
      MapNavigationVoicePolicy.formatDistanceForSpeech(1500),
      '1,5 quilômetros',
    );
    expect(
      MapNavigationVoicePolicy.formatDistanceForSpeech(1000),
      '1 quilômetro',
    );
  });
}
