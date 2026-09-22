part of 'monitor_screen.dart';

extension _MonitorMulticamera on _MonitorScreenState {
  VideoSourceConfig _sourceForEndpoint(CameraEndpoint camera) =>
      switch (camera.type) {
        CameraEndpointType.local => VideoSourceConfig(
          type: VideoSourceType.localCamera,
          displayName: camera.name,
          cameraId: camera.id,
          analysisInterval: _controller.sourceConfig.analysisInterval,
        ),
        CameraEndpointType.rtsp => VideoSourceConfig(
          type: VideoSourceType.rtsp,
          rtspUrl: camera.address,
          displayName: camera.name,
          cameraId: camera.id,
          analysisInterval: _controller.sourceConfig.analysisInterval,
        ),
        CameraEndpointType.remotePhone => VideoSourceConfig(
          type: VideoSourceType.remotePhone,
          remoteBaseUrl: camera.address,
          remoteAccessKey: camera.accessKey,
          displayName: camera.name,
          cameraId: camera.id,
          analysisInterval: _controller.sourceConfig.analysisInterval,
        ),
        CameraEndpointType.esp32 => VideoSourceConfig(
          type: VideoSourceType.esp32,
          remoteBaseUrl: camera.address,
          remoteAccessKey: camera.accessKey,
          displayName: camera.name,
          cameraId: camera.id,
          analysisInterval: _controller.sourceConfig.analysisInterval,
        ),
      };

  bool _sameSource(VideoSourceConfig first, VideoSourceConfig second) {
    if (first.type != second.type) return false;
    if (first.cameraId != null && second.cameraId != null) {
      return first.cameraId == second.cameraId;
    }
    return switch (first.type) {
      VideoSourceType.localCamera => true,
      VideoSourceType.rtsp => first.rtspUrl == second.rtspUrl,
      VideoSourceType.remotePhone =>
        first.remoteBaseUrl == second.remoteBaseUrl,
      VideoSourceType.esp32 => first.remoteBaseUrl == second.remoteBaseUrl,
    };
  }

  Future<void> _replaceSecondarySource(VideoSourceConfig? source) async {
    final previous = _secondaryController;
    previous?.removeListener(_refresh);
    _updateMulticameraState(() => _secondaryController = null);
    previous?.dispose();
    if (source == null || !mounted) return;
    final next = SecondaryCameraController(sourceConfig: source)
      ..addListener(_refresh);
    _updateMulticameraState(() => _secondaryController = next);
    await next.start();
  }

  Future<void> _showSecondaryCameraSelector() async {
    await _cameraRegistry.initialize();
    if (!mounted) return;
    final cameras = <CameraEndpoint>[
      const CameraEndpoint(
        id: '__local__',
        name: 'Câmera deste aparelho',
        type: CameraEndpointType.local,
      ),
      ..._cameraRegistry.items.where(
        (camera) =>
            camera.enabled &&
            (camera.type != CameraEndpointType.esp32 ||
                camera.esp32CameraEnabled),
      ),
    ];
    final candidates = cameras
        .where((camera) {
          return !_sameSource(
            _controller.sourceConfig,
            _sourceForEndpoint(camera),
          );
        })
        .toList(growable: false);

    final selectedId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Câmeras do Monitor'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, '__single__'),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.filter_1_rounded),
              title: Text('Usar somente uma câmera'),
              subtitle: Text('A câmera principal ocupa toda a área de vídeo.'),
            ),
          ),
          ...candidates.map(
            (camera) => SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, camera.id),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(switch (camera.type) {
                  CameraEndpointType.local => Icons.camera_alt_outlined,
                  CameraEndpointType.rtsp => Icons.router_outlined,
                  CameraEndpointType.remotePhone => Icons.phone_android_rounded,
                  CameraEndpointType.esp32 => Icons.memory_rounded,
                }),
                title: Text(camera.name),
                subtitle: Text(switch (camera.type) {
                  CameraEndpointType.local => 'Segunda visualização local',
                  CameraEndpointType.rtsp => 'Segunda visualização RTSP',
                  CameraEndpointType.remotePhone =>
                    'Segundo celular transmissor',
                  CameraEndpointType.esp32 => 'Segunda câmera do ESP32',
                }),
                trailing:
                    _secondaryController?.sourceConfig.cameraId == camera.id
                    ? const Icon(Icons.check_circle_rounded)
                    : null,
              ),
            ),
          ),
          if (candidates.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 18),
              child: Text(
                'Cadastre outra fonte na Central multicâmera para dividir a tela.',
              ),
            ),
        ],
      ),
    );
    if (selectedId == null || !mounted) return;
    if (selectedId == '__single__') {
      await _replaceSecondarySource(null);
      return;
    }
    final selectedIndex = candidates.indexWhere(
      (item) => item.id == selectedId,
    );
    if (selectedIndex < 0) return;
    final camera = candidates[selectedIndex];
    if (camera.type == CameraEndpointType.local) {
      final granted = await NativePlatformService.instance
          .requestCameraPermission();
      if (!mounted) return;
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permita a câmera para usar a segunda imagem local.'),
          ),
        );
        return;
      }
    }
    await _replaceSecondarySource(_sourceForEndpoint(camera));
  }

  Widget _buildAdaptiveCameraStage(
    BuildContext context, {
    bool portraitEmbedded = false,
  }) {
    if (_secondaryController == null) {
      return _buildCameraStage(context, portraitEmbedded: portraitEmbedded);
    }
    return _buildDualCameraStage(context, portraitEmbedded: portraitEmbedded);
  }

  Widget _buildDualCameraStage(
    BuildContext context, {
    bool portraitEmbedded = false,
  }) {
    final secondary = _secondaryController!;
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final insets = _fullscreen || landscape
        ? MediaQuery.viewPaddingOf(context)
        : EdgeInsets.zero;
    final bikeSnapshot = _effectiveBikeSnapshot;
    final status = _controller.sourceStatus;
    final approach = _controller.bikeApproachStatus;
    final showCompactTopHud =
        (landscape || _fullscreen) &&
        (!_fullscreen || _fullscreenControlsVisible);

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final layout = adaptiveCameraLayoutFor(
                cameraCount: 2,
                landscape: landscape,
                availableWidth: constraints.maxWidth,
              );
              final primary = _buildPrimaryCameraTile(context);
              final second = _buildSecondaryCameraTile(context, secondary);
              if (layout == AdaptiveCameraLayout.sideBySide) {
                return Row(
                  children: [
                    Expanded(child: primary),
                    const SizedBox(width: 4),
                    Expanded(child: second),
                  ],
                );
              }
              return Column(
                children: [
                  Expanded(child: primary),
                  const SizedBox(height: 4),
                  Expanded(child: second),
                ],
              );
            },
          ),
          if (showCompactTopHud)
            Positioned(
              left: 8 + insets.left,
              right: 8 + insets.right,
              top: 6 + insets.top,
              child: _CompactMonitorTopHud(
                sourceStatus: status,
                detectionCount: _currentDetectionCount,
                bikeSnapshot: bikeSnapshot,
                approach: approach,
                deviceStrip: _buildDeviceStrip(
                  status: status,
                  secondary: secondary,
                ),
                fillPreview: true,
                fullscreen: _fullscreen,
                fullscreenChanging: _fullscreenChanging,
                voiceEnabled: _controller.voiceEnabled,
                detectionDelayed: _controller.detectionDelayed,
                processing: _controller.processing,
                onClose: () => unawaited(_closeMonitor()),
                onFullscreen: _fullscreenChanging
                    ? null
                    : () => unawaited(_toggleFullscreen()),
                onToggleFill: () =>
                    _updateMulticameraState(() => _fillPreview = !_fillPreview),
                onToggleVoice: () =>
                    _controller.setVoiceEnabled(!_controller.voiceEnabled),
                menu: _monitorMenu(),
              ),
            )
          else if (!portraitEmbedded)
            Positioned(
              left: 8,
              right: 8,
              top: 6,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (bikeSnapshot != null) BikeRideHud(snapshot: bikeSnapshot),
                  if (bikeSnapshot != null) const SizedBox(height: 6),
                  _buildDeviceStrip(status: status, secondary: secondary),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _HudPill(
                          icon: Icons.psychology_alt_outlined,
                          label: _controller.processing
                              ? 'IA analisando'
                              : 'IA na principal',
                          active: true,
                        ),
                        _HudPill(
                          icon: Icons.video_collection_outlined,
                          label: '2 câmeras',
                          active: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (_controller.detectionDelayed)
            Positioned(
              left: 12 + insets.left,
              right: 12 + insets.right,
              bottom: 12 + insets.bottom,
              child: const IgnorePointer(
                child: Material(
                  color: Colors.black87,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'IA atrasada · alertas aguardam imagem recente',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeviceStrip({
    required VideoSourceStatus status,
    required SecondaryCameraController secondary,
    bool embedded = false,
  }) => _DeviceStatusStrip(
    localDevice: _controller.localDeviceTelemetry,
    remoteStatus: _controller.remotePhoneStatus,
    sourceType: _controller.sourceConfig.type,
    sourceStatus: status,
    receiverActive: !_controller.initializing && _controller.error == null,
    networkLatencyMs: _controller.sessionStatus.networkLatencyMs,
    secondarySourceType: secondary.sourceConfig.type,
    secondarySourceStatus: secondary.status,
    secondaryRemoteStatus: secondary.remoteStatus,
    secondaryLabel: secondary.displayName,
    embedded: embedded,
    onTap: () => unawaited(_showSessionStatus()),
  );

  Widget _buildPrimaryCameraTile(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!_controller.initializing) _buildPreviewLayer(context),
          if (_controller.initializing)
            const Center(child: CircularProgressIndicator()),
          if (!_controller.initializing)
            DetectionOverlay(
              detections: _controller.detections,
              trackedDetections: _controller.trackedDetections,
              previewAspectRatio: _controller.previewAspectRatio,
              fillPreview: true,
            ),
          if (!_controller.initializing)
            MonitoringZoneOverlay(
              zones: _controller.monitoringZones,
              editingZoneId: _editingZoneId,
              previewAspectRatio: _controller.previewAspectRatio,
              fillPreview: true,
              onChanged: _applyZone,
            ),
          Positioned(
            left: 8,
            bottom: 8,
            child: _CameraPaneLabel(
              title: _controller.sourceConfig.displayName ?? 'Câmera principal',
              detail: 'Principal · IA e alertas',
              active:
                  _controller.sourceStatus.state == VideoSourceState.streaming,
            ),
          ),
          if (_controller.error != null)
            Positioned(
              left: 8,
              right: 8,
              bottom: 54,
              child: _CameraErrorCard(
                message: _controller.error!,
                onRetry: _controller.initializing
                    ? null
                    : () => unawaited(_controller.retry()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSecondaryCameraTile(
    BuildContext context,
    SecondaryCameraController secondary,
  ) {
    final streaming = secondary.status.state == VideoSourceState.streaming;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          secondary.buildPreview(),
          if (secondary.initializing)
            const Center(child: CircularProgressIndicator()),
          Positioned(
            left: 8,
            bottom: 8,
            child: _CameraPaneLabel(
              title: secondary.displayName,
              detail: 'Visualização · IA na principal',
              active: streaming,
            ),
          ),
          if (secondary.error != null)
            Positioned(
              left: 8,
              right: 8,
              bottom: 54,
              child: _CameraErrorCard(
                message: secondary.error!,
                onRetry: secondary.initializing
                    ? null
                    : () => unawaited(secondary.start()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraStage(
    BuildContext context, {
    bool portraitEmbedded = false,
  }) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final insets = _fullscreen || landscape
        ? MediaQuery.viewPaddingOf(context)
        : EdgeInsets.zero;
    final status = _controller.sourceStatus;
    final remoteStatus = _controller.remotePhoneStatus;
    final bikeSnapshot = _effectiveBikeSnapshot;
    final bikeHudActive = bikeSnapshot != null;
    final approach = _controller.bikeApproachStatus;
    final compactTopHud = landscape || _fullscreen;
    final showCompactTopHud =
        compactTopHud && (!_fullscreen || _fullscreenControlsVisible);
    final compactBikeHud = MediaQuery.sizeOf(context).height < 500;
    final bikeHudBottom = bikeHudActive
        ? (bikeSnapshot.primaryWarning == null
              ? (compactBikeHud ? 72.0 : 98.0)
              : (compactBikeHud ? 108.0 : 138.0))
        : 6.0;
    final standardHudTop = approach.visible
        ? bikeHudBottom + (compactBikeHud ? 48.0 : 58.0)
        : (bikeHudActive ? bikeHudBottom : 12.0);
    final deviceStripTop = standardHudTop + insets.top;
    final standardControlsTop = deviceStripTop + 48;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!_controller.initializing) _buildPreviewLayer(context),
          if (_controller.initializing)
            const Center(child: CircularProgressIndicator()),
          if (!_controller.initializing)
            DetectionOverlay(
              detections: _controller.detections,
              trackedDetections: _controller.trackedDetections,
              previewAspectRatio: _controller.previewAspectRatio,
              fillPreview: _fillPreview,
            ),
          if (!_controller.initializing)
            MonitoringZoneOverlay(
              zones: _controller.monitoringZones,
              editingZoneId: _editingZoneId,
              previewAspectRatio: _controller.previewAspectRatio,
              fillPreview: _fillPreview,
              onChanged: _applyZone,
            ),
          if (showCompactTopHud)
            Positioned(
              left: 8 + insets.left,
              right: 8 + insets.right,
              top: 6 + insets.top,
              child: _CompactMonitorTopHud(
                sourceStatus: status,
                detectionCount: _currentDetectionCount,
                bikeSnapshot: bikeSnapshot,
                approach: approach,
                deviceStrip: _DeviceStatusStrip(
                  localDevice: _controller.localDeviceTelemetry,
                  remoteStatus: remoteStatus,
                  sourceType: _controller.sourceConfig.type,
                  sourceStatus: status,
                  receiverActive:
                      !_controller.initializing && _controller.error == null,
                  networkLatencyMs: _controller.sessionStatus.networkLatencyMs,
                  onTap: () => unawaited(_showSessionStatus()),
                ),
                fillPreview: _fillPreview || landscape || _fullscreen,
                fullscreen: _fullscreen,
                fullscreenChanging: _fullscreenChanging,
                voiceEnabled: _controller.voiceEnabled,
                detectionDelayed: _controller.detectionDelayed,
                processing: _controller.processing,
                onClose: () => unawaited(_closeMonitor()),
                onFullscreen: _fullscreenChanging
                    ? null
                    : () => unawaited(_toggleFullscreen()),
                onToggleFill: () =>
                    _updateMulticameraState(() => _fillPreview = !_fillPreview),
                onToggleVoice: () =>
                    _controller.setVoiceEnabled(!_controller.voiceEnabled),
                menu: _monitorMenu(),
              ),
            ),
          if (!portraitEmbedded && !compactTopHud && bikeHudActive)
            Positioned(
              left: 0,
              right: 0,
              top: 6 + insets.top,
              child: Padding(
                padding: EdgeInsets.only(
                  left: insets.left,
                  right: insets.right,
                ),
                child: BikeRideHud(snapshot: bikeSnapshot),
              ),
            ),
          if (!portraitEmbedded && !compactTopHud && approach.visible)
            Positioned(
              left: 10,
              right: 10,
              top: bikeHudBottom + insets.top,
              child: BikeApproachBanner(status: approach),
            ),
          if (!portraitEmbedded && !compactTopHud)
            Positioned(
              left: 8 + insets.left,
              right: 8 + insets.right,
              top: deviceStripTop,
              child: _DeviceStatusStrip(
                localDevice: _controller.localDeviceTelemetry,
                remoteStatus: remoteStatus,
                sourceType: _controller.sourceConfig.type,
                sourceStatus: status,
                receiverActive:
                    !_controller.initializing && _controller.error == null,
                networkLatencyMs: _controller.sessionStatus.networkLatencyMs,
                onTap: () => unawaited(_showSessionStatus()),
              ),
            ),
          if (!portraitEmbedded && !_fullscreen && !compactTopHud)
            Positioned(
              left: 12,
              right: 12,
              top: standardControlsTop,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _HudPill(
                        icon: status.state == VideoSourceState.streaming
                            ? Icons.fiber_manual_record_rounded
                            : Icons.videocam_off_outlined,
                        label: _statusText(status),
                        active: status.state == VideoSourceState.streaming,
                      ),
                      _HudPill(
                        icon: Icons.psychology_alt_outlined,
                        label: _controller.detectionDelayed
                            ? 'IA atrasada'
                            : _controller.processing
                            ? 'IA analisando'
                            : 'IA ativa',
                        active: !_controller.initializing,
                      ),
                      _HudPill(
                        icon: _hudExpanded
                            ? Icons.expand_less_rounded
                            : Icons.more_horiz_rounded,
                        label: _hudExpanded ? 'Ocultar' : 'Painel',
                        active: false,
                        onTap: () => _updateMulticameraState(
                          () => _hudExpanded = !_hudExpanded,
                        ),
                      ),
                    ],
                  ),
                  if (remoteStatus != null &&
                      remoteStatus.warnings().isNotEmpty) ...[
                    const SizedBox(height: 7),
                    RemoteBikeWarningBanner(
                      status: remoteStatus,
                      onTap: _showRemoteBikeStatus,
                    ),
                  ],
                  if (_hudExpanded) ...[
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _HudPill(
                          icon: Icons.grid_view_rounded,
                          label: _controller.activeMonitoringZones.isEmpty
                              ? 'Tela inteira'
                              : '${_controller.activeMonitoringZones.length} áreas',
                          active: true,
                        ),
                        if (_controller.backgroundMonitoringEnabled)
                          const _HudPill(
                            icon: Icons.phone_android_rounded,
                            label: '2º plano',
                            active: true,
                          ),
                        if (_controller.clipRecordingEnabled)
                          _HudPill(
                            icon: Icons.movie_outlined,
                            label: _controller.clipRecording
                                ? 'Gravando clipe'
                                : 'Clipes',
                            active: _controller.clipRecording,
                          ),
                        _HudPill(
                          icon: _fillPreview
                              ? Icons.fullscreen_rounded
                              : Icons.fit_screen_rounded,
                          label: _fillPreview ? 'Preencher' : 'Ajustar',
                          active: _fillPreview,
                          onTap: () => _updateMulticameraState(
                            () => _fillPreview = !_fillPreview,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          if (portraitEmbedded)
            Positioned(
              left: 10,
              bottom: 10,
              child: _CameraPaneLabel(
                title:
                    _controller.sourceConfig.displayName ??
                    switch (_controller.sourceConfig.type) {
                      VideoSourceType.localCamera => 'Câmera local',
                      VideoSourceType.rtsp => 'Câmera RTSP',
                      VideoSourceType.remotePhone => 'Celular remoto',
                      VideoSourceType.esp32 => 'Câmera ESP32',
                    },
                detail: 'Principal · IA e alertas',
                active: status.state == VideoSourceState.streaming,
              ),
            ),
          if (_controller.detectionDelayed)
            Positioned(
              left: 12 + insets.left,
              right: 12 + insets.right,
              bottom:
                  (portraitEmbedded ? 58 : (_fullscreen ? 78 : 160)) +
                  insets.bottom,
              child: const IgnorePointer(
                child: Material(
                  color: Colors.black87,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'IA atrasada · alertas aguardam imagem recente',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          if (_editingZoneId != null)
            Positioned(
              right: 12,
              bottom: 12,
              child: IconButton.filledTonal(
                tooltip: 'Cancelar edição da área',
                onPressed: () =>
                    _updateMulticameraState(() => _editingZoneId = null),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          if (_controller.error != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: _editingZoneId == null ? 12 : 72,
              child: _CameraErrorCard(
                message: _controller.error!,
                onRetry: _controller.initializing
                    ? null
                    : () => unawaited(_controller.retry()),
              ),
            ),
        ],
      ),
    );
  }
}
