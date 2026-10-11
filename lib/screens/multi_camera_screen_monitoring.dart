part of 'multi_camera_screen.dart';

extension _MultiCameraMonitoring on _MultiCameraScreenState {
  VideoSourceConfig _sourceFor(
    CameraEndpoint camera,
    Duration analysisInterval,
  ) => switch (camera.type) {
        CameraEndpointType.local => VideoSourceConfig(
            type: VideoSourceType.localCamera,
            displayName: camera.name,
            cameraId: camera.id,
            analysisInterval: analysisInterval,
          ),
        CameraEndpointType.rtsp => VideoSourceConfig(
            type: VideoSourceType.rtsp,
            rtspUrl: camera.address,
            rtspSoftwareDecoding: camera.rtspSoftwareDecoding,
            displayName: camera.name,
            cameraId: camera.id,
            analysisInterval: analysisInterval,
          ),
        CameraEndpointType.remotePhone => VideoSourceConfig(
            type: VideoSourceType.remotePhone,
            remoteBaseUrl: camera.address,
            remoteAccessKey: camera.accessKey,
            displayName: camera.name,
            cameraId: camera.id,
            analysisInterval: analysisInterval,
          ),
        CameraEndpointType.esp32 => VideoSourceConfig(
            type: VideoSourceType.esp32,
            remoteBaseUrl: camera.address,
            remoteAccessKey: camera.accessKey,
            displayName: camera.name,
            cameraId: camera.id,
            analysisInterval: analysisInterval,
          ),
      };

  Future<void> _openWithSecond(CameraEndpoint primary) async {
    final candidates = _cameras
        .where((camera) =>
            camera.enabled &&
            camera.id != primary.id &&
            (camera.type != CameraEndpointType.esp32 ||
                camera.esp32CameraEnabled))
        .toList(growable: false);
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastre e ative outra câmera para dividir a tela.'),
        ),
      );
      return;
    }
    final selected = await showDialog<CameraEndpoint>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Escolha a segunda câmera'),
        children: candidates
            .map((camera) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, camera),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(switch (camera.type) {
                      CameraEndpointType.local => Icons.camera_alt_outlined,
                      CameraEndpointType.rtsp => Icons.router_outlined,
                      CameraEndpointType.remotePhone => Icons.phone_android_rounded,
                      CameraEndpointType.esp32 => Icons.memory_rounded,
                    }),
                    title: Text(camera.name),
                    subtitle: Text(_status[camera.id]?.online == true
                        ? 'Online'
                        : 'Conexão será tentada ao abrir'),
                  ),
                ))
            .toList(growable: false),
      ),
    );
    if (selected != null && mounted) {
      await _open(primary, secondary: selected);
    }
  }

  Future<void> _open(
    CameraEndpoint camera, {
    CameraEndpoint? secondary,
  }) async {
    if (!camera.enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ative esta câmera antes de monitorar.')),
      );
      return;
    }
    if (camera.type == CameraEndpointType.esp32 &&
        !camera.esp32CameraEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Habilite a câmera deste ESP32 antes de monitorar.'),
        ),
      );
      return;
    }
    if (camera.type == CameraEndpointType.rtsp ||
        secondary?.type == CameraEndpointType.rtsp) {
      final rtsp = camera.type == CameraEndpointType.rtsp ? camera : secondary!;
      // Persistir antes de navegar: uma falha de codec nativo pode matar o
      // processo sem passar pelos handlers Dart ou pela Central de Erros.
      await RtspDiagnosticsService.instance.mark(
        'open_requested', address: rtsp.address,
      );
      await ErrorLogService.instance.record(
        level: ErrorLogLevel.info,
        source: 'RTSP',
        message: 'Abertura de câmera RTSP solicitada.',
        context: <String, Object?>{
          'cameraId': rtsp.id,
          'host': RtspDiagnosticsService.safeHost(rtsp.address),
          'segundaCamera': secondary?.type == CameraEndpointType.rtsp,
        },
      );
    }
    // Porta fechada ou IP inacessível não deve inicializar o player nativo.
    // Isso NÃO substitui a negociação RTSP nem valida o codec.
    for (final rtsp in <CameraEndpoint>[
      if (camera.type == CameraEndpointType.rtsp) camera,
      if (secondary?.type == CameraEndpointType.rtsp) secondary!,
    ]) {
      final probe = await _registry.probe(rtsp);
      if (!mounted) return;
      if (!probe.online) {
        await RtspDiagnosticsService.instance.mark(
          'source_error', address: rtsp.address,
        );
        await ErrorLogService.instance.record(
          level: ErrorLogLevel.warning,
          source: 'RTSP',
          message: 'A porta RTSP não respondeu. O player não foi iniciado.',
          context: <String, Object?>{
            'cameraId': rtsp.id,
            'host': RtspDiagnosticsService.safeHost(rtsp.address),
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Câmera RTSP inacessível. Confira IP, porta e rede.'),
          ));
        }
        return;
      }
    }
    final profile = await _settings.initialize();
    if (camera.type == CameraEndpointType.local ||
        secondary?.type == CameraEndpointType.local) {
      final granted = await _native.requestCameraPermission();
      if (!mounted) return;
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'A permissão da câmera é necessária para monitorar este dispositivo.',
            ),
            action: SnackBarAction(
              label: 'AJUSTES',
              onPressed: () => unawaited(_native.openAppSettings()),
            ),
          ),
        );
        return;
      }
    }
    if (profile.settings.backgroundMonitoringEnabled) {
      await _native.requestNotificationPermission();
      if (!mounted) return;
    }
    final source = _sourceFor(camera, profile.source.analysisInterval);
    final secondarySource = secondary == null
        ? null
        : _sourceFor(secondary, profile.source.analysisInterval);
    if (!mounted) return;
    _statusTimer?.cancel();
    _statusTimer = null;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => MonitorScreen(
            initialSource: source,
            settings: profile.settings,
            secondarySource: secondarySource,
          ),
        ),
      );
    } catch (error, stackTrace) {
      await ErrorLogService.instance.recordException(
        source: 'Abertura RTSP/multicâmera',
        error: error,
        stackTrace: stackTrace,
        message: 'Não foi possível abrir o monitor.',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Não foi possível abrir o monitor. Veja o diagnóstico.'),
        ));
      }
    }
    await _history.initialize();
    if (!mounted) return;
    _statusTimer = Timer.periodic(
      _MultiCameraScreenState._automaticRefreshInterval,
      (_) => unawaited(_refreshStatuses()),
    );
    _updateMonitoringState(() {});
    unawaited(_refreshStatuses());
  }

}
