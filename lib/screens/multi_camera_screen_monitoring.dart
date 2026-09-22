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
      };

  Future<void> _openWithSecond(CameraEndpoint primary) async {
    final candidates = _cameras
        .where((camera) => camera.enabled && camera.id != primary.id)
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
