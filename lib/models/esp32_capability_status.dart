import 'esp32_module.dart';
import 'esp32_telemetry.dart';

enum Esp32CapabilityActivity {
  live,
  detected,
  waiting,
  offline,
  discovered,
}

extension Esp32CapabilityActivityLabel on Esp32CapabilityActivity {
  String get label => switch (this) {
        Esp32CapabilityActivity.live => 'Lendo agora',
        Esp32CapabilityActivity.detected => 'Detectado',
        Esp32CapabilityActivity.waiting => 'Aguardando leitura',
        Esp32CapabilityActivity.offline => 'Módulo offline',
        Esp32CapabilityActivity.discovered => 'Detectado · não configurado',
      };
}

class Esp32CapabilityObservation {
  const Esp32CapabilityObservation({
    required this.capability,
    required this.activity,
    required this.configured,
    required this.advertised,
    required this.hasLiveReading,
    this.valueLabel,
  });

  final Esp32Capability capability;
  final Esp32CapabilityActivity activity;
  final bool configured;
  final bool advertised;
  final bool hasLiveReading;
  final String? valueLabel;

  bool get needsAttention => activity == Esp32CapabilityActivity.discovered;
}

List<Esp32CapabilityObservation> buildEsp32CapabilityObservations(
  Esp32Module module,
  Esp32RuntimeState? runtime,
) {
  final packet = runtime?.packet;
  final inferred = packet == null
      ? const <Esp32Capability>{}
      : inferEsp32CapabilitiesFromTelemetry(packet);
  final capabilities = <Esp32Capability>{
    ...module.capabilities,
    ...?packet?.reportedCapabilities,
    ...inferred,
  }.toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  final online = runtime?.connectionState == Esp32ConnectionState.online;

  return capabilities
      .map(
        (capability) => Esp32CapabilityObservation(
          capability: capability,
          configured: module.supports(capability),
          advertised: packet?.reportedCapabilities.contains(capability) ?? false,
          hasLiveReading:
              packet != null && capabilityHasLiveReading(capability, packet),
          valueLabel:
              packet == null ? null : capabilityValueLabel(capability, packet),
          activity: _activityFor(
            configured: module.supports(capability),
            advertised:
                packet?.reportedCapabilities.contains(capability) ?? false,
            hasLiveReading:
                packet != null && capabilityHasLiveReading(capability, packet),
            online: online,
          ),
        ),
      )
      .toList(growable: false);
}

Set<Esp32Capability> inferEsp32CapabilitiesFromTelemetry(
  Esp32TelemetryPacket packet,
) {
  final inferred = <Esp32Capability>{};
  final bike = packet.bikePayload;

  if (bike['temperatureC'] is num) inferred.add(Esp32Capability.temperature);
  if (bike['speedKmh'] is num || bike['tripDistanceKm'] is num) {
    inferred.add(Esp32Capability.hallSpeed);
  }
  if (bike['frontTirePsi'] is num || bike['rearTirePsi'] is num) {
    inferred.add(Esp32Capability.tirePressure);
  }
  if (packet.batteryPercent != null ||
      packet.batteryVoltage != null ||
      packet.charging != null) {
    inferred.add(Esp32Capability.battery);
  }
  if (packet.energy != null) inferred.add(Esp32Capability.energy);

  return inferred;
}

bool capabilityHasLiveReading(
  Esp32Capability capability,
  Esp32TelemetryPacket packet,
) {
  final bike = packet.bikePayload;
  return switch (capability) {
    Esp32Capability.temperature => bike['temperatureC'] is num,
    Esp32Capability.hallSpeed =>
      bike['speedKmh'] is num || bike['tripDistanceKm'] is num,
    Esp32Capability.tirePressure =>
      bike['frontTirePsi'] is num || bike['rearTirePsi'] is num,
    Esp32Capability.battery =>
      packet.batteryPercent != null ||
          packet.batteryVoltage != null ||
          packet.charging != null,
    Esp32Capability.energy => packet.energy != null,
    _ => false,
  };
}

String? capabilityValueLabel(
  Esp32Capability capability,
  Esp32TelemetryPacket packet,
) {
  final bike = packet.bikePayload;
  return switch (capability) {
    Esp32Capability.temperature => _temperatureLabel(bike['temperatureC']),
    Esp32Capability.hallSpeed => _hallLabel(bike),
    Esp32Capability.tirePressure => _tireLabel(bike),
    Esp32Capability.battery => _moduleBatteryLabel(packet),
    Esp32Capability.energy => _energyLabel(packet.energy),
    _ => null,
  };
}

Esp32CapabilityActivity _activityFor({
  required bool configured,
  required bool advertised,
  required bool hasLiveReading,
  required bool online,
}) {
  if (!configured && (advertised || hasLiveReading)) {
    return Esp32CapabilityActivity.discovered;
  }
  if (!online) return Esp32CapabilityActivity.offline;
  if (hasLiveReading) return Esp32CapabilityActivity.live;
  if (advertised) return Esp32CapabilityActivity.detected;
  return Esp32CapabilityActivity.waiting;
}

String? _temperatureLabel(Object? value) {
  if (value is! num) return null;
  return '${value.toStringAsFixed(1)} °C';
}

String? _hallLabel(Map<String, dynamic> bike) {
  final speed = bike['speedKmh'];
  final distance = bike['tripDistanceKm'];
  final parts = <String>[];
  if (speed is num) parts.add('${speed.toStringAsFixed(1)} km/h');
  if (distance is num) parts.add('${distance.toStringAsFixed(2)} km');
  return parts.isEmpty ? null : parts.join(' · ');
}

String? _tireLabel(Map<String, dynamic> bike) {
  final front = bike['frontTirePsi'];
  final rear = bike['rearTirePsi'];
  final parts = <String>[];
  if (front is num) parts.add('D ${front.toStringAsFixed(0)} PSI');
  if (rear is num) parts.add('T ${rear.toStringAsFixed(0)} PSI');
  return parts.isEmpty ? null : parts.join(' · ');
}

String? _moduleBatteryLabel(Esp32TelemetryPacket packet) {
  final parts = <String>[];
  if (packet.batteryPercent != null) parts.add('${packet.batteryPercent}%');
  if (packet.batteryVoltage != null) {
    parts.add('${packet.batteryVoltage!.toStringAsFixed(2)} V');
  }
  if (packet.charging == true) parts.add('alimentação externa');
  return parts.isEmpty ? null : parts.join(' · ');
}

String? _energyLabel(Esp32EnergyTelemetry? energy) {
  if (energy == null) return null;
  final parts = <String>[];
  if (energy.batteryPercent != null) parts.add('${energy.batteryPercent}%');
  if (energy.voltageV != null) {
    parts.add('${energy.voltageV!.toStringAsFixed(2)} V');
  }
  if (energy.currentA != null) {
    parts.add('${energy.currentA!.toStringAsFixed(2)} A');
  }
  if (energy.powerW != null) parts.add('${energy.powerW!.toStringAsFixed(1)} W');
  if (energy.charging == true) parts.add('carregando');
  if (energy.batteryTemperatureC != null) {
    parts.add('bat. ${energy.batteryTemperatureC!.toStringAsFixed(1)} °C');
  }
  if (energy.solarPowerW != null) {
    parts.add('solar ${energy.solarPowerW!.toStringAsFixed(1)} W');
  }
  if (energy.energyInWh != null) {
    parts.add('entrada ${energy.energyInWh!.toStringAsFixed(1)} Wh');
  }
  if (energy.energyOutWh != null) {
    parts.add('saída ${energy.energyOutWh!.toStringAsFixed(1)} Wh');
  }
  return parts.isEmpty ? null : parts.join(' · ');
}
