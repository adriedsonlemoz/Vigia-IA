import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/remote_phone_status.dart';

void main() {
  test('status remoto converte telemetria, perfil, FPS e latência', () {
    final receivedAt = DateTime.utc(2026, 9, 19, 21);
    final status = RemotePhoneStatus.fromJson(
      <String, dynamic>{
        'online': true,
        'lastFrameAt': '2026-09-19T20:59:59.000Z',
        'bikeMode': true,
        'bikeProfile': 'economy',
        'alertLowBattery': true,
        'lowBatteryPercent': 20,
        'fps': 5.8,
        'name': 'Vigia IA - câmera remota',
        'device': <String, dynamic>{
          'capturedAt': '2026-09-19T20:59:58.000Z',
          'batteryPercent': 73,
          'batteryCharging': true,
          'batteryTemperatureC': 31.2,
          'screenBrightnessPercent': 4,
          'appCpuPercent': 22.5,
          'memoryAvailableBytes': 3000,
          'memoryTotalBytes': 8000,
        },
      },
      receivedAt: receivedAt,
      networkLatencyMs: 37,
    );

    expect(status.online, isTrue);
    expect(status.bikeMode, isTrue);
    expect(status.profileLabel, 'Economia');
    expect(status.cameraFps, 5.8);
    expect(status.networkLatencyMs, 37);
    expect(status.device?.batteryPercent, 73);
    expect(status.device?.createdAt, DateTime.utc(2026, 9, 19, 20, 59, 58));
    expect(status.warnings(receivedAt), isEmpty);
  });

  test('painel remoto sinaliza bateria, temperatura, CPU e RAM críticas', () {
    final now = DateTime.utc(2026, 9, 19, 21);
    final status = RemotePhoneStatus.fromJson(
      <String, dynamic>{
        'online': true,
        'bikeMode': true,
        'bikeProfile': 'extremeEconomy',
        'lowBatteryPercent': 20,
        'device': <String, dynamic>{
          'batteryPercent': 8,
          'batteryCharging': false,
          'batteryTemperatureC': 46.1,
          'appCpuPercent': 91.0,
          'memoryAvailableBytes': 500,
          'memoryTotalBytes': 10000,
        },
      },
      receivedAt: now,
    );

    final warnings = status.warnings(now);
    expect(warnings.map((item) => item.code), containsAll(<String>[
      'battery_low',
      'battery_hot',
      'cpu_high',
      'memory_low',
    ]));
    expect(
      warnings.where((item) => item.code == 'battery_low').single.level,
      RemotePhoneWarningLevel.critical,
    );
    expect(
      warnings.where((item) => item.code == 'battery_hot').single.level,
      RemotePhoneWarningLevel.critical,
    );
  });

  test('telemetria sem atualização recente é marcada como atrasada', () {
    final receivedAt = DateTime.utc(2026, 9, 19, 20, 59, 30);
    final now = DateTime.utc(2026, 9, 19, 21);
    final status = RemotePhoneStatus(
      receivedAt: receivedAt,
      online: true,
      bikeMode: true,
      name: 'Traseiro',
    );

    expect(status.isStale(now), isTrue);
    expect(
      status.warnings(now).any((item) => item.code == 'telemetry_stale'),
      isTrue,
    );
  });
}
