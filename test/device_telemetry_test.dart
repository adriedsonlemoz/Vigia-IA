import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/device_telemetry.dart';

void main() {
  test('telemetria converte dados nativos e preserva tipos', () {
    final snapshot = DeviceTelemetrySnapshot.fromMap(<Object?, Object?>{
      'batteryPercent': 73,
      'batteryCharging': true,
      'batteryPowerSource': 'USB',
      'batteryCurrentMa': 842,
      'batteryTemperatureC': 31.4,
      'screenBrightnessPercent': 4,
      'automaticBrightness': false,
      'screenInteractive': true,
      'screenDimmedByBike': true,
      'appCpuPercent': 18.75,
      'processorCount': 8,
      'memoryUsedBytes': 123456789,
      'memoryAvailableBytes': 2222222222,
      'memoryTotalBytes': 4444444444,
      'freeStorageBytes': 5555555555,
      'totalStorageBytes': 9999999999,
    });

    expect(snapshot.batteryPercent, 73);
    expect(snapshot.batteryCharging, isTrue);
    expect(snapshot.batteryPowerSource, 'USB');
    expect(snapshot.batteryCurrentMa, 842.0);
    expect(snapshot.batteryTemperatureC, 31.4);
    expect(snapshot.screenBrightnessPercent, 4);
    expect(snapshot.screenDimmedByBike, isTrue);
    expect(snapshot.appCpuPercent, 18.75);
    expect(snapshot.processorCount, 8);
    expect(snapshot.appMemoryUsedBytes, 123456789);
    expect(snapshot.memoryTotalBytes, 4444444444);
  });

  test('telemetria serializa payload que pode ser enviado ao receptor', () {
    final capturedAt = DateTime.utc(2026, 9, 19, 18, 30);
    final snapshot = DeviceTelemetrySnapshot(
      createdAt: capturedAt,
      batteryPercent: 41,
      batteryCharging: false,
      screenDimmedByBike: true,
      appCpuPercent: 7.5,
      memoryAvailableBytes: 1024,
      memoryTotalBytes: 2048,
    );

    final json = snapshot.toJson();
    expect(json['capturedAt'], capturedAt.toIso8601String());
    expect(json['batteryPercent'], 41);
    expect(json['batteryCharging'], isFalse);
    expect(json['screenDimmedByBike'], isTrue);
    expect(json['appCpuPercent'], 7.5);
    expect(json['memoryAvailableBytes'], 1024);
    expect(json['memoryTotalBytes'], 2048);
  });

  test('telemetria tolera campos indisponíveis no aparelho', () {
    final snapshot = DeviceTelemetrySnapshot.fromMap(<Object?, Object?>{});
    expect(snapshot.batteryPercent, isNull);
    expect(snapshot.batteryCurrentMa, isNull);
    expect(snapshot.appCpuPercent, isNull);
    expect(snapshot.screenDimmedByBike, isFalse);
  });
  test('telemetria remota preserva o horário capturado no payload', () {
    final snapshot = DeviceTelemetrySnapshot.fromJson(<String, dynamic>{
      'capturedAt': '2026-09-19T21:15:00.000Z',
      'batteryPercent': 64,
    });

    expect(snapshot.createdAt, DateTime.utc(2026, 9, 19, 21, 15));
    expect(snapshot.batteryPercent, 64);
  });

}
