import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/system_health.dart';

SystemHealthSnapshot snapshot({
  bool monitoring = false,
  bool service = false,
  bool camera = false,
  bool frames = false,
  bool ai = false,
}) {
  return SystemHealthSnapshot(
    createdAt: DateTime(2026, 9, 17, 22),
    monitoringActive: monitoring,
    androidServiceActive: service,
    cameraActive: camera,
    framesActive: frames,
    aiReady: true,
    aiActive: ai,
  );
}

void main() {
  test('servico ativo sem captura nao e marcado como funcionando', () {
    final value = snapshot(service: true);
    expect(value.operationalState, SystemOperationalState.idle);
  });

  test('monitor ativo sem frames exige atencao', () {
    final value = snapshot(
      monitoring: true,
      service: true,
      camera: false,
      frames: false,
      ai: false,
    );
    expect(value.operationalState, SystemOperationalState.attention);
  });

  test('saude so fica positiva com camera frames e IA ativos', () {
    final value = snapshot(
      monitoring: true,
      service: true,
      camera: true,
      frames: true,
      ai: true,
    );
    expect(value.operationalState, SystemOperationalState.healthy);
  });
}
