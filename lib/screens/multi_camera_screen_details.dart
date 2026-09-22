part of 'multi_camera_screen.dart';

class _CameraDetails extends StatelessWidget {
  const _CameraDetails({
    required this.camera,
    required this.cameraAvailable,
    required this.status,
    required this.remoteStatus,
  });

  final CameraEndpoint camera;
  final bool cameraAvailable;
  final CameraProbeResult? status;
  final RemotePhoneStatus? remoteStatus;

  @override
  Widget build(BuildContext context) {
    final detail = switch (camera.type) {
      CameraEndpointType.local =>
        'Dispositivo: este celular · sensor disponível ao iniciar',
      CameraEndpointType.rtsp =>
        'Endereço RTSP cadastrado · resolução informada ao abrir o vídeo',
      CameraEndpointType.esp32 => _esp32Detail(),
      CameraEndpointType.remotePhone => _remoteDetail(),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        detail,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  String _remoteDetail() {
    final remote = remoteStatus;
    if (remote == null) {
      return status?.message ?? 'Aguardando informações do celular remoto.';
    }
    final device = [remote.device?.deviceManufacturer, remote.device?.deviceModel]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join(' ');
    final information = <String>[
      if (device.isNotEmpty) device,
      if (remote.videoWidth != null && remote.videoHeight != null)
        '${remote.videoWidth}×${remote.videoHeight}',
      if (remote.cameraFps != null) '${remote.cameraFps!.toStringAsFixed(0)} FPS',
      if (remote.device?.batteryPercent != null)
        '${remote.device!.batteryPercent}% bateria',
    ];
    return information.isEmpty
        ? 'Celular remoto online · aguardando detalhes da transmissão.'
        : information.join(' · ');
  }

  String _esp32Detail() {
    if (!cameraAvailable) {
      return 'Sensores ativos · câmera ESP32 ainda não habilitada.';
    }
    final sensors = <String>[
      if (camera.temperatureSensorEnabled) 'temperatura',
      if (camera.hallSensorEnabled) 'Hall',
      if (camera.tirePressureEnabled) 'pneus',
    ];
    return sensors.isEmpty
        ? 'Câmera ESP32 habilitada · aguardando informações do módulo.'
        : 'Câmera ESP32 habilitada · sensores: ${sensors.join(', ')}.';
  }
}
