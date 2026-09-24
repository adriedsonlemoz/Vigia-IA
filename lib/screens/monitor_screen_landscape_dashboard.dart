part of 'monitor_screen.dart';

extension _MonitorLandscapeDashboard on _MonitorScreenState {
  Future<void> _initializeMiniMap({required bool requestPermission}) async {
    await _mapRoute.initialize(requestPermission: requestPermission);
    if (mounted) _updateMulticameraState(() {});
  }

  bool get _shouldShowMonitorMap => _mapRoute.shouldShowInMonitor(
        bikeConnected: _effectiveBikeSnapshot?.connected == true,
      );

  double get _miniMapDistanceKm {
    final bikeSnapshot = _effectiveBikeSnapshot;
    if (bikeSnapshot != null && bikeSnapshot.tripDistanceKm > 0) {
      return bikeSnapshot.tripDistanceKm;
    }
    return _mapRoute.distanceMeters / 1000;
  }

  Future<void> _showLandscapeDetections() async {
    await _showRightSidePanel(
      maxWidth: 460,
      builder: (context) => SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Detectados agora',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildDetectionPanel(context, compact: false)),
          ],
        ),
      ),
    );
  }

  Future<void> _showLandscapeQuickActions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Ações do monitor',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Controles rápidos para ajustar a sessão ao vivo sem poluir a tela principal.',
              ),
              const SizedBox(height: 12),
              _buildControlDock(sheetContext, compact: true),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: const Text('Abrir mapa completo'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_openStandardScreen(_mapMonitoringScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.list_alt_rounded),
                title: const Text('Eventos'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_openStandardScreen(const EventsScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.wifi_tethering_rounded),
                title: const Text('Rede local'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_showLanAccess());
                },
              ),
              ListTile(
                leading: const Icon(Icons.monitor_heart_outlined),
                title: const Text('Status da sessão'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_showSessionStatus());
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Configurações'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_openStandardScreen(const SettingsScreen()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFullMap() async {
    await _openStandardScreen(_mapMonitoringScreen());
  }


  Widget _buildLandscapeDashboard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = _controller.sourceStatus;
    final bikeSnapshot = _effectiveBikeSnapshot;
    final approach = _controller.bikeApproachStatus;
    final remoteWarnings = _controller.remotePhoneStatus?.warnings() ??
        const <String>[];
    final width = MediaQuery.sizeOf(context).width;
    final mapWidth = (width * 0.34).clamp(300.0, 470.0).toDouble();
    final mapCurrent = _miniMapCurrent;
    final mapCenter = mapCurrent == null
        ? const LatLng(-14.2350, -51.9253)
        : LatLng(mapCurrent.latitude, mapCurrent.longitude);
    final mapPolylines = _miniMapSegments
        .map(
          (segment) => segment
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList(growable: false),
        )
        .where((segment) => segment.length >= 2)
        .toList(growable: false);
    final locationReady =
        _miniMapAvailability == LocationTrackingAvailability.ready;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF071221), Color(0xFF050A12)],
        ),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Voltar',
                        onPressed: () => unawaited(_closeMonitor()),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ao vivo',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Modo Bike · Monitoramento em tempo real',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            alignment: WrapAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => unawaited(_closeMonitor()),
                                icon: const Icon(
                                  Icons.stop_circle_outlined,
                                  size: 18,
                                ),
                                label: const Text('Encerrar'),
                              ),
                              IconButton(
                                tooltip: _fullscreen
                                    ? 'Sair da tela inteira'
                                    : 'Tela inteira',
                                onPressed: _fullscreenChanging
                                    ? null
                                    : () => unawaited(_toggleFullscreen()),
                                icon: Icon(
                                  _fullscreen
                                      ? Icons.fullscreen_exit_rounded
                                      : Icons.fullscreen_rounded,
                                ),
                              ),
                              _voiceButton(),
                              _monitorMenu(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
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
                          icon: Icons.radar_rounded,
                          label: 'Detectados $_currentDetectionCount',
                          active: _currentDetectionCount > 0,
                          onTap: () => unawaited(_showLandscapeDetections()),
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
                        if (bikeSnapshot?.simulated == true)
                          const _HudPill(
                            icon: Icons.science_outlined,
                            label: 'SIMULAÇÃO',
                            active: true,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.30),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.18),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
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
                          Positioned(
                            left: 14,
                            top: 14,
                            child: _DashboardCameraBadge(
                              icon: Icons.videocam_rounded,
                              label: _controller.sourceConfig.displayName ??
                                  switch (_controller.sourceConfig.type) {
                                    VideoSourceType.localCamera => 'Câmera local',
                                    VideoSourceType.rtsp => 'Câmera RTSP',
                                    VideoSourceType.remotePhone => 'Outro celular',
                                    VideoSourceType.esp32 => 'Câmera ESP32',
                                  },
                              active: status.state == VideoSourceState.streaming,
                            ),
                          ),
                          Positioned(
                            left: 14,
                            bottom: 14,
                            child: _DashboardCameraBadge(
                              icon: Icons.high_quality_rounded,
                              label: _controller.previewAspectRatio == null
                                  ? 'Imagem ao vivo'
                                  : 'Prévia ao vivo',
                              active: true,
                            ),
                          ),
                          if (approach.visible)
                            Positioned(
                              top: 14,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 420),
                                  child: BikeApproachBanner(status: approach),
                                ),
                              ),
                            ),
                          if (remoteWarnings.isNotEmpty)
                            Positioned(
                              left: 14,
                              right: 14,
                              bottom: _controller.error == null ? 60 : 116,
                              child: RemoteBikeWarningBanner(
                                status: _controller.remotePhoneStatus!,
                                onTap: _showRemoteBikeStatus,
                              ),
                            ),
                          Positioned(
                            right: 14,
                            bottom: 14,
                            child: FilledButton.tonalIcon(
                              onPressed: _fullscreenChanging
                                  ? null
                                  : () => unawaited(_toggleFullscreen()),
                              icon: const Icon(Icons.fullscreen_rounded),
                              label: const Text('Expandir'),
                            ),
                          ),
                          if (_controller.error != null)
                            Positioned(
                              left: 14,
                              right: 14,
                              bottom: 14,
                              child: _CameraErrorCard(
                                message: _controller.error!,
                                onRetry: _controller.initializing
                                    ? null
                                    : () => unawaited(_controller.retry()),
                              ),
                            ),
                          if (_primaryContentMode != _MonitorPrimaryContentMode.camera)
                            Positioned.fill(
                              child: _primaryContentMode == _MonitorPrimaryContentMode.map
                                  ? LayoutBuilder(
                                      builder: (context, constraints) => _buildPortraitMapCard(
                                        context,
                                        height: constraints.maxHeight,
                                      ),
                                    )
                                  : ColoredBox(
                                      color: Colors.black,
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.videocam_off_rounded, size: 48),
                                            const SizedBox(height: 10),
                                            const Text('Câmera desligada', style: TextStyle(fontWeight: FontWeight.w800)),
                                            TextButton.icon(
                                              onPressed: () => unawaited(_setPrimaryContentMode(_MonitorPrimaryContentMode.camera)),
                                              icon: const Icon(Icons.videocam_rounded),
                                              label: const Text('Ligar câmera'),
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
                  const SizedBox(width: 12),
                  SizedBox(
                    width: mapWidth,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.30),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.map_outlined, color: scheme.primary),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Mapa do trajeto',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      'Acompanhamento em tempo real',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => unawaited(_openFullMap()),
                                icon: const Icon(Icons.route_rounded, size: 18),
                                label: const Text('Ver rota completa'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerLowest,
                                  border: Border.all(
                                    color: scheme.primary.withValues(alpha: 0.18),
                                  ),
                                ),
                                child: _miniMapLoading
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : !locationReady
                                    ? _MapUnavailableState(
                                        availability: _miniMapAvailability,
                                        onEnable: () => unawaited(
                                          _initializeMiniMap(
                                            requestPermission: true,
                                          ),
                                        ),
                                        onOpenFullMap: () =>
                                            unawaited(_openFullMap()),
                                      )
                                    : Stack(
                                        children: [
                                          FlutterMap(
                                            mapController: _miniMapController,
                                            options: MapOptions(
                                              initialCenter: mapCenter,
                                              initialZoom: mapCurrent == null ? 12 : 15.8,
                                              minZoom: 3,
                                              maxZoom: 19,
                                              onMapReady: () {
                                                _miniMapReady = true;
                                                final point = _miniMapCurrent;
                                                if (point != null) {
                                                  _miniMapController.move(
                                                    LatLng(
                                                      point.latitude,
                                                      point.longitude,
                                                    ),
                                                    15.8,
                                                  );
                                                }
                                              },
                                            ),
                                            children: [
                                              if (_miniOfflineTileProvider != null)
                                                TileLayer(
                                                  key: ValueKey<String>(
                                                    'mini-offline-${_miniOfflinePackageId ?? 'active'}',
                                                  ),
                                                  tileProvider: _miniOfflineTileProvider,
                                                  minNativeZoom: _miniOfflineMinZoom,
                                                  maxNativeZoom: _miniOfflineMaxZoom,
                                                ),
                                              if (_offlineMaps.mode !=
                                                  OfflineMapMode.offline)
                                                TileLayer(
                                                  urlTemplate:
                                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                                  userAgentPackageName:
                                                      'com.vigiaia.app',
                                                  maxNativeZoom: 19,
                                                ),
                                              if (mapPolylines.isNotEmpty)
                                                PolylineLayer(
                                                  polylines: mapPolylines
                                                      .map(
                                                        (points) => Polyline(
                                                          points: points,
                                                          strokeWidth: 4,
                                                          color: scheme.primary,
                                                        ),
                                                      )
                                                      .toList(growable: false),
                                                ),
                                              MarkerLayer(
                                                markers: [
                                                  if (_miniMapRoute.isNotEmpty)
                                                    Marker(
                                                      point: LatLng(
                                                        _miniMapRoute.first.latitude,
                                                        _miniMapRoute.first.longitude,
                                                      ),
                                                      width: 34,
                                                      height: 34,
                                                      child: const Icon(
                                                        Icons.flag_rounded,
                                                        color: Colors.green,
                                                        size: 26,
                                                      ),
                                                    ),
                                                  if (mapCurrent != null)
                                                    Marker(
                                                      point: LatLng(
                                                        mapCurrent.latitude,
                                                        mapCurrent.longitude,
                                                      ),
                                                      width: 44,
                                                      height: 44,
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          color: scheme.primary
                                                              .withValues(alpha: 0.20),
                                                        ),
                                                        alignment: Alignment.center,
                                                        child: Container(
                                                          width: 18,
                                                          height: 18,
                                                          decoration: BoxDecoration(
                                                            shape: BoxShape.circle,
                                                            color: scheme.primary,
                                                            border: Border.all(
                                                              color: Colors.white,
                                                              width: 3,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (approach.visible && mapCurrent != null)
                                                    Marker(
                                                      point: LatLng(
                                                        mapCurrent.latitude,
                                                        mapCurrent.longitude,
                                                      ),
                                                      width: 58,
                                                      height: 58,
                                                      child: Align(
                                                        alignment: const Alignment(0.70, -0.70),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets.all(6),
                                                          decoration: BoxDecoration(
                                                            color: scheme.error,
                                                            shape: BoxShape.circle,
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: scheme.error
                                                                    .withValues(alpha: 0.45),
                                                                blurRadius: 12,
                                                              ),
                                                            ],
                                                          ),
                                                          child: const Icon(
                                                            Icons.priority_high_rounded,
                                                            size: 18,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Positioned(
                                            right: 12,
                                            top: 12,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.62),
                                                borderRadius: BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: Colors.white.withValues(alpha: 0.08),
                                                ),
                                              ),
                                              child: const Padding(
                                                padding: EdgeInsets.fromLTRB(10, 8, 10, 8),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    _MapLegendItem(
                                                      color: Color(0xFF4EA0FF),
                                                      label: 'Sua posição',
                                                    ),
                                                    SizedBox(height: 6),
                                                    _MapLegendItem(
                                                      color: Colors.green,
                                                      label: 'Início do trajeto',
                                                    ),
                                                    SizedBox(height: 6),
                                                    _MapLegendItem(
                                                      color: Color(0xFFEF5350),
                                                      label: 'Alerta',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            left: 12,
                                            bottom: 12,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.65),
                                                borderRadius: BorderRadius.circular(18),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _miniMapDistanceKm < 1
                                                          ? '${(_miniMapDistanceKm * 1000).toStringAsFixed(0)} m'
                                                          : '${_miniMapDistanceKm.toStringAsFixed(1)} km',
                                                      style: const TextStyle(
                                                        fontSize: 28,
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      bikeSnapshot != null
                                                          ? 'Distância pela bike'
                                                          : 'Distância percorrida',
                                                      style: theme.textTheme.bodySmall,
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
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _DashboardMetricCard(
                  icon: Icons.speed_rounded,
                  label: 'Velocidade',
                  value: bikeSnapshot == null
                      ? '--'
                      : bikeSnapshot.speedKmh.toStringAsFixed(0),
                  unit: 'km/h',
                ),
                _DashboardMetricCard(
                  icon: Icons.device_thermostat_rounded,
                  label: 'Temperatura',
                  value: () {
                    final temperature = bikeSnapshot?.ambientTemperatureC;
                    return temperature == null
                        ? '--'
                        : temperature.toStringAsFixed(0);
                  }(),
                  unit: '°C',
                ),
                _DashboardMetricCard(
                  icon: Icons.tire_repair_rounded,
                  label: 'Pneu dianteiro',
                  value: bikeSnapshot == null
                      ? '--'
                      : bikeSnapshot.frontTirePsi.toStringAsFixed(0),
                  unit: 'PSI',
                ),
                _DashboardMetricCard(
                  icon: Icons.album_outlined,
                  label: 'Pneu traseiro',
                  value: bikeSnapshot == null
                      ? '--'
                      : bikeSnapshot.rearTirePsi.toStringAsFixed(0),
                  unit: 'PSI',
                ),
                _DashboardMetricCard(
                  icon: Icons.route_rounded,
                  label: 'Distância',
                  value: _miniMapDistanceKm < 1
                      ? (_miniMapDistanceKm * 1000).toStringAsFixed(0)
                      : _miniMapDistanceKm.toStringAsFixed(1),
                  unit: _miniMapDistanceKm < 1 ? 'm' : 'km',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DeviceStatusStrip(
              localDevice: _controller.localDeviceTelemetry,
              remoteStatus: _controller.remotePhoneStatus,
              sourceType: _controller.sourceConfig.type,
              sourceStatus: status,
              receiverActive: !_controller.initializing && _controller.error == null,
              networkLatencyMs: _controller.sessionStatus.networkLatencyMs,
              onTap: () => unawaited(_showSessionStatus()),
              embedded: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _DashboardActionButton(icon: Icons.videocam_outlined, label: 'Câmera', accent: _primaryContentMode != _MonitorPrimaryContentMode.cameraOff, onPressed: () => unawaited(_showCameraHub()))),
                const SizedBox(width: 8),
                Expanded(child: _DashboardActionButton(icon: Icons.map_outlined, label: 'Mapa', accent: true, onPressed: () => unawaited(_showMapExplorerSheet()))),
                const SizedBox(width: 8),
                Expanded(child: _DashboardActionButton(icon: _controller.voiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded, label: 'Áudio', onPressed: () => _controller.setVoiceEnabled(!_controller.voiceEnabled))),
                const SizedBox(width: 8),
                Expanded(child: _DashboardActionButton(icon: Icons.tune_rounded, label: 'Painel', onPressed: () => unawaited(_showSessionStatus()))),
                const SizedBox(width: 8),
                Expanded(child: _DashboardActionButton(icon: Icons.settings_outlined, label: 'Ajustes', onPressed: () => unawaited(_openStandardScreen(const SettingsScreen())))),
              ],
            ),
          ],
        ),
      ),
    );
  }

}
