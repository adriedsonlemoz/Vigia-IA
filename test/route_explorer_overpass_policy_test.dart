import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/route_explorer_overpass_policy.dart';

void main() {
  final now = DateTime.utc(2026, 10, 12, 12);
  test('HTTP 429 segura apenas o servidor afetado por 3 minutos', () {
    final policy = RouteExplorerOverpassPolicy();
    policy.failed('a', now: now, httpStatus: 429);
    expect(policy.canAttempt('a', now: now.add(const Duration(minutes: 2))), isFalse);
    expect(policy.canAttempt('b', now: now), isTrue);
    expect(policy.canAttempt('a', now: now.add(const Duration(minutes: 3))), isTrue);
  });
  test('HTTP 504 provoca espera distinta de erro transitório', () {
    final policy = RouteExplorerOverpassPolicy();
    policy.failed('a', now: now, httpStatus: 504);
    policy.failed('b', now: now);
    expect(policy.canAttempt('a', now: now.add(const Duration(seconds: 60))), isFalse);
    expect(policy.canAttempt('b', now: now.add(const Duration(seconds: 30))), isTrue);
  });
  test('Retry-After maior estende espera, menor não encurta', () {
    final policy = RouteExplorerOverpassPolicy();
    policy.failed('a', now: now, httpStatus: 429, retryAfter: '600');
    expect(policy.canAttempt('a', now: now.add(const Duration(minutes: 4))), isFalse);
    expect(policy.canAttempt('a', now: now.add(const Duration(minutes: 10))), isTrue);
    policy.failed('b', now: now, httpStatus: 429, retryAfter: '10');
    expect(policy.canAttempt('b', now: now.add(const Duration(minutes: 2))), isFalse);
  });
  test('resposta bem-sucedida libera bloqueio do endpoint', () {
    final policy = RouteExplorerOverpassPolicy();
    policy.failed('a', now: now, httpStatus: 429);
    policy.succeeded('a');
    expect(policy.canAttempt('a', now: now), isTrue);
  });
  test('Retry-After HTTP-date é respeitado', () {
    final policy = RouteExplorerOverpassPolicy();
    policy.failed('a', now: now, httpStatus: 429,
        retryAfter: 'Mon, 12 Oct 2026 12:20:00 GMT');
    expect(policy.canAttempt('a', now: now.add(const Duration(minutes: 19))), isFalse);
    expect(policy.canAttempt('a', now: now.add(const Duration(minutes: 20))), isTrue);
  });
}
