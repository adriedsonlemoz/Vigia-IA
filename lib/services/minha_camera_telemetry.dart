import '../models/device_telemetry.dart';
import '../models/remote_phone_status.dart';

/// Converte apenas os cabeçalhos documentados do Minha Câmera (MCRP v1).
/// Não confunde temperatura da bateria com temperatura ambiente ou do sensor.
class MinhaCameraTelemetry {
  const MinhaCameraTelemetry._();

  static RemotePhoneStatus fromHeaders(Map<String, String> headers, {
    DateTime? receivedAt,
    int? networkLatencyMs,
  }) {
    final now = receivedAt ?? DateTime.now();
    int? boundedInt(String header, int min, int max) {
      final value = int.tryParse(headers[header]?.trim() ?? '');
      return value != null && value >= min && value <= max ? value : null;
    }

    final battery = boundedInt('x-battery-level', 0, 100);
    final temperatureTenths = boundedInt('x-battery-temp-tenths', -400, 1000);
    final fps = boundedInt('x-fps-target', 1, 120);
    final model = headers['x-device-model']?.trim();
    final resolution = RegExp(r'^(\d{2,5})[x×](\d{2,5})$')
        .firstMatch(headers['x-resolution']?.trim() ?? '');
    return RemotePhoneStatus(
      receivedAt: now,
      online: true,
      bikeMode: false,
      name: 'Minha Câmera',
      networkLatencyMs: networkLatencyMs,
      device: DeviceTelemetrySnapshot(
        createdAt: now,
        deviceModel: model == null || model.isEmpty ? null : model,
        batteryPercent: battery,
        batteryTemperatureC: temperatureTenths == null
            ? null
            : temperatureTenths / 10.0,
      ),
      cameraFps: fps?.toDouble(),
      videoWidth: resolution == null ? null : int.tryParse(resolution.group(1)!),
      videoHeight: resolution == null ? null : int.tryParse(resolution.group(2)!),
    );
  }
}
