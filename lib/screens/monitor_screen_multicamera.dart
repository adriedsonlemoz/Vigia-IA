part of 'monitor_screen.dart';

extension _MonitorMulticamera on _MonitorScreenState {
  Future<void> _setPrimaryContentMode(_MonitorPrimaryContentMode mode) async {
    if (_primaryContentMode == mode) return;
    _updateMulticameraState(() => _primaryContentMode = mode);
    if (mode == _MonitorPrimaryContentMode.camera) {
      await _controller.resume();
      await _secondaryController?.resume();
    } else {
      await _controller.suspend();
      await _secondaryController?.suspend();
    }
  }

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
    if (first.type == VideoSourceType.localCamera) {
      final firstIsFrontTest = first.isFrontCameraTest;
      final secondIsFrontTest = second.isFrontCameraTest;
      if (firstIsFrontTest || secondIsFrontTest) {
        return firstIsFrontTest && secondIsFrontTest;
      }
      return true;
    }
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

  VideoSourceConfig _frontCameraTestSource() => VideoSourceConfig(
    type: VideoSourceType.localCamera,
    displayName: 'Frontal (teste)',
    cameraId: frontCameraTestId,
    analysisInterval: _controller.sourceConfig.analysisInterval,
  );

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
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, frontCameraTestId),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.face_retouching_natural_outlined),
              title: const Text('Teste: câmera frontal'),
              subtitle: const Text(
                'Abre a frontal em uma janela pequena; a IA continua somente na principal.',
              ),
              trailing:
                  _secondaryController?.sourceConfig.cameraId ==
                      frontCameraTestId
                  ? const Icon(Icons.check_circle_rounded)
                  : null,
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
    if (selectedId == frontCameraTestId) {
      final granted = await NativePlatformService.instance
          .requestCameraPermission();
      if (!mounted) return;
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permita a câmera para testar a frontal.'),
          ),
        );
        return;
      }
      await _replaceSecondarySource(_frontCameraTestSource());
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

  IconData _cameraEndpointIcon(CameraEndpointType type) => switch (type) {
    CameraEndpointType.local => Icons.camera_alt_outlined,
    CameraEndpointType.rtsp => Icons.router_outlined,
    CameraEndpointType.remotePhone => Icons.phone_android_rounded,
    CameraEndpointType.esp32 => Icons.memory_rounded,
  };

  Future<bool> _ensureLocalCameraPermission() async {
    final granted = await NativePlatformService.instance.requestCameraPermission();
    if (!mounted) return false;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permita a câmera para usar esta fonte.')),
      );
    }
    return granted;
  }

  Future<void> _selectPrimaryCamera(CameraEndpoint camera) async {
    final next = _sourceForEndpoint(camera);
    if (next.type == VideoSourceType.localCamera &&
        !await _ensureLocalCameraPermission()) {
      return;
    }
    final secondary = _secondaryController?.sourceConfig;
    if (secondary != null && _sameSource(next, secondary)) {
      await _replaceSecondarySource(null);
    }
    await _controller.switchSource(next);
  }

  Future<void> _selectSecondaryCamera(VideoSourceConfig source) async {
    if (_sameSource(_controller.sourceConfig, source)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Essa fonte já está sendo usada como câmera principal.'),
        ),
      );
      return;
    }
    if (source.type == VideoSourceType.localCamera &&
        !await _ensureLocalCameraPermission()) {
      return;
    }
    await _replaceSecondarySource(source);
  }

  Future<void> _showCameraHub() async {
    await _cameraRegistry.initialize();
    if (!mounted) return;
    final cameras = <CameraEndpoint>[
      const CameraEndpoint(
        id: '__local__',
        name: 'Câmera local',
        type: CameraEndpointType.local,
      ),
      ..._cameraRegistry.items.where(
        (camera) =>
            camera.enabled &&
            (camera.type != CameraEndpointType.esp32 ||
                camera.esp32CameraEnabled),
      ),
    ];
    var useTwoCameras = _secondaryController != null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final secondaryCandidates = cameras
              .where(
                (camera) => !_sameSource(
                  _controller.sourceConfig,
                  _sourceForEndpoint(camera),
                ),
              )
              .toList(growable: false);
          return SafeArea(
            child: FractionallySizedBox(
              heightFactor: 0.78,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                children: [
                  const Text(
                    'Câmeras',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Escolha o que ocupa a área principal e, quando a câmera estiver ligada, selecione as fontes.',
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<_MonitorPrimaryContentMode>(
                    segments: const [
                      ButtonSegment(value: _MonitorPrimaryContentMode.camera, icon: Icon(Icons.videocam_rounded), label: Text('Ligada')),
                      ButtonSegment(value: _MonitorPrimaryContentMode.cameraOff, icon: Icon(Icons.videocam_off_rounded), label: Text('Desligada')),
                      ButtonSegment(value: _MonitorPrimaryContentMode.map, icon: Icon(Icons.map_rounded), label: Text('Mapa')),
                    ],
                    selected: <_MonitorPrimaryContentMode>{_primaryContentMode},
                    onSelectionChanged: (selection) {
                      unawaited(_setPrimaryContentMode(selection.first));
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_primaryContentMode == _MonitorPrimaryContentMode.camera) ...[
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        icon: Icon(Icons.filter_1_rounded),
                        label: Text('1 câmera'),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        icon: Icon(Icons.filter_2_rounded),
                        label: Text('2 câmeras'),
                      ),
                    ],
                    selected: <bool>{useTwoCameras},
                    onSelectionChanged: (selection) {
                      final enabled = selection.first;
                      setSheetState(() => useTwoCameras = enabled);
                      if (!enabled) unawaited(_replaceSecondarySource(null));
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Câmera principal',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  ...cameras.map((camera) {
                    final source = _sourceForEndpoint(camera);
                    final selected = _sameSource(_controller.sourceConfig, source);
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: Icon(_cameraEndpointIcon(camera.type)),
                      title: Text(camera.name),
                      subtitle: Text(switch (camera.type) {
                        CameraEndpointType.local => 'Câmera deste aparelho',
                        CameraEndpointType.rtsp => 'Câmera de rede RTSP',
                        CameraEndpointType.remotePhone => 'Outro celular',
                        CameraEndpointType.esp32 => 'Câmera do módulo ESP32',
                      }),
                      trailing: selected
                          ? const Icon(Icons.check_circle_rounded)
                          : null,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        unawaited(_selectPrimaryCamera(camera));
                      },
                    );
                  }),
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: const Icon(Icons.face_retouching_natural_outlined),
                    title: const Text('Câmera frontal'),
                    subtitle: const Text('Usa a frontal como segunda câmera de teste.'),
                    trailing:
                        _secondaryController?.sourceConfig.cameraId ==
                            frontCameraTestId
                        ? const Icon(Icons.check_circle_rounded)
                        : null,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      unawaited(
                        _selectSecondaryCamera(_frontCameraTestSource()),
                      );
                    },
                  ),
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: const Icon(Icons.add_link_rounded),
                    title: const Text('Configurar outra fonte'),
                    subtitle: const Text('RTSP, outro celular ou ESP32 manual.'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      unawaited(_showSourceSwitcher());
                    },
                  ),
                  if (useTwoCameras) ...[
                    const Divider(height: 24),
                    const Text(
                      'Segunda câmera',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    ...secondaryCandidates.map((camera) {
                      final source = _sourceForEndpoint(camera);
                      final selected = _secondaryController != null &&
                          _sameSource(
                            _secondaryController!.sourceConfig,
                            source,
                          );
                      return ListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        leading: Icon(_cameraEndpointIcon(camera.type)),
                        title: Text(camera.name),
                        subtitle: Text(switch (camera.type) {
                          CameraEndpointType.local => 'Câmera local secundária',
                          CameraEndpointType.rtsp => 'Segunda câmera RTSP',
                          CameraEndpointType.remotePhone => 'Segundo celular',
                          CameraEndpointType.esp32 => 'Segunda câmera ESP32',
                        }),
                        trailing: selected
                            ? const Icon(Icons.check_circle_rounded)
                            : null,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          unawaited(_selectSecondaryCamera(source));
                        },
                      );
                    }),
                  ],
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdaptiveCameraStage(
    BuildContext context, {
    bool portraitEmbedded = false,
  }) {
    final secondary = _secondaryController;
    if (secondary == null) {
      return _buildCameraStage(context, portraitEmbedded: portraitEmbedded);
    }
    final portrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    if (portraitEmbedded && portrait) {
      return _buildPortraitPictureInPictureStage(context, secondary);
    }
    return _buildDualCameraStage(context, portraitEmbedded: portraitEmbedded);
  }

  Widget _buildPortraitPictureInPictureStage(
    BuildContext context,
    SecondaryCameraController secondary,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final pipWidth = (constraints.maxWidth * 0.30)
            .clamp(92.0, 122.0)
            .toDouble();
        final pipHeight = (constraints.maxHeight * 0.38)
            .clamp(72.0, 104.0)
            .toDouble();
        final streaming =
            secondary.status.state == VideoSourceState.streaming;
        final maxLeft = (constraints.maxWidth - pipWidth - 6)
            .clamp(6.0, constraints.maxWidth)
            .toDouble();
        final maxTop = (constraints.maxHeight - pipHeight - 6)
            .clamp(6.0, constraints.maxHeight)
            .toDouble();
        final fallbackPosition = Offset(maxLeft, maxTop);
        final requestedPosition = _portraitPipOffset ?? fallbackPosition;
        final pipPosition = Offset(
          requestedPosition.dx.clamp(6.0, maxLeft).toDouble(),
          requestedPosition.dy.clamp(6.0, maxTop).toDouble(),
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            _buildCameraStage(context, portraitEmbedded: true),
            Positioned(
              left: pipPosition.dx,
              top: pipPosition.dy,
              width: pipWidth,
              height: pipHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) {
                  final current = _portraitPipOffset ?? fallbackPosition;
                  _updateMulticameraState(() {
                    _portraitPipOffset = Offset(
                      (current.dx + details.delta.dx)
                          .clamp(6.0, maxLeft)
                          .toDouble(),
                      (current.dy + details.delta.dy)
                          .clamp(6.0, maxTop)
                          .toDouble(),
                    );
                  });
                },
                child: Material(
                  color: Colors.black,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.72),
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        secondary.buildPreview(),
                        if (secondary.initializing)
                          const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        if (secondary.error != null)
                          Padding(
                            padding: const EdgeInsets.all(7),
                            child: Center(
                              child: Text(
                                'Frontal indisponível\nem simultâneo',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          left: 4,
                          right: 4,
                          bottom: 4,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.68),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: streaming
                                          ? const Color(0xFF69D59C)
                                          : const Color(0xFFFFB4AB),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      secondary.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
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
              title: switch (_controller.sourceConfig.type) {
                VideoSourceType.localCamera => 'Local',
                VideoSourceType.rtsp =>
                  _controller.sourceConfig.displayName ?? 'RTSP',
                VideoSourceType.remotePhone =>
                  _controller.sourceConfig.displayName ?? 'Remota',
                VideoSourceType.esp32 =>
                  _controller.sourceConfig.displayName ?? 'ESP32',
              },
              detail: 'Principal',
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
                title: switch (_controller.sourceConfig.type) {
                  VideoSourceType.localCamera => 'Local',
                  VideoSourceType.rtsp =>
                    _controller.sourceConfig.displayName ?? 'RTSP',
                  VideoSourceType.remotePhone =>
                    _controller.sourceConfig.displayName ?? 'Remota',
                  VideoSourceType.esp32 =>
                    _controller.sourceConfig.displayName ?? 'ESP32',
                },
                detail: null,
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
