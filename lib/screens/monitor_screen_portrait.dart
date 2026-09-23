part of 'monitor_screen.dart';

extension _MonitorPortraitLayout on _MonitorScreenState {
  Widget _buildPortrait(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final status = _controller.sourceStatus;
        final secondary = _secondaryController;
        final bikeSnapshot = _effectiveBikeSnapshot;
        final previewRatio = _controller.previewAspectRatio;
        final horizontalFeed = (previewRatio ?? 0) > 1.05;
        final width = constraints.maxWidth - 20;
        final calculatedCameraHeight = previewRatio != null && previewRatio > 0
            ? width / previewRatio
            : constraints.maxHeight * 0.32;
        final cameraHeight = secondary != null
            ? (constraints.maxHeight * 0.30).clamp(220.0, 320.0).toDouble()
            : horizontalFeed
            ? calculatedCameraHeight.clamp(210.0, 320.0).toDouble()
            : bikeSnapshot == null
            ? (constraints.maxHeight * 0.36).clamp(260.0, 420.0).toDouble()
            : (constraints.maxHeight * 0.31).clamp(220.0, 340.0).toDouble();
        final mapHeight = secondary == null
            ? (constraints.maxHeight * 0.22).clamp(170.0, 230.0).toDouble()
            : 0.0;
        final detectionHeight = (constraints.maxHeight * 0.30)
            .clamp(240.0, 320.0)
            .toDouble();

        return ColoredBox(
          color: scheme.surface,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 8),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (bikeSnapshot != null)
                    _buildPortraitMetricsStrip(context, bikeSnapshot),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                    child: secondary == null
                        ? _DeviceStatusStrip(
                            localDevice: _controller.localDeviceTelemetry,
                            remoteStatus: _controller.remotePhoneStatus,
                            sourceType: _controller.sourceConfig.type,
                            sourceStatus: status,
                            receiverActive:
                                !_controller.initializing &&
                                _controller.error == null,
                            networkLatencyMs:
                                _controller.sessionStatus.networkLatencyMs,
                            onTap: () => unawaited(_showSessionStatus()),
                            embedded: true,
                          )
                        : _buildDeviceStrip(
                            status: status,
                            secondary: secondary,
                            embedded: true,
                          ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Container(
                      height: cameraHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.34),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _buildAdaptiveCameraStage(
                        context,
                        portraitEmbedded: true,
                      ),
                    ),
                  ),
                  if (secondary == null) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: _buildPortraitMapCard(
                        context,
                        height: mapHeight,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildPortraitActionRow(context),
                    const SizedBox(height: 10),
                  ] else ...[
                    const SizedBox(height: 8),
                    _buildPortraitActionRow(context),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    height: detectionHeight,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.28),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _buildDetectionPanel(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPortraitMetricsStrip(
    BuildContext context,
    BikeSensorSnapshot bikeSnapshot,
  ) {
    final cards = [
      _DashboardMetricCard(
        icon: Icons.speed_rounded,
        label: 'Velocidade',
        value: bikeSnapshot.speedKmh.toStringAsFixed(0),
        unit: 'km/h',
      ),
      _DashboardMetricCard(
        icon: Icons.device_thermostat_rounded,
        label: 'Temperatura',
        value: bikeSnapshot.ambientTemperatureC == null
            ? '--'
            : bikeSnapshot.ambientTemperatureC!.toStringAsFixed(0),
        unit: '°C',
      ),
      _DashboardMetricCard(
        icon: Icons.tire_repair_rounded,
        label: 'Pneu dianteiro',
        value: bikeSnapshot.frontTirePsi.toStringAsFixed(0),
        unit: 'PSI',
      ),
      _DashboardMetricCard(
        icon: Icons.album_outlined,
        label: 'Pneu traseiro',
        value: bikeSnapshot.rearTirePsi.toStringAsFixed(0),
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
    ];
    return SizedBox(
      height: 96,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) => cards[index],
      ),
    );
  }

  Widget _buildPortraitMapCard(
    BuildContext context, {
    required double height,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mapCurrent = _miniMapCurrent;
    final mapCenter = mapCurrent == null
        ? const LatLng(-14.2350, -51.9253)
        : LatLng(mapCurrent.latitude, mapCurrent.longitude);
    final mapPolyline = _miniMapRoute
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);
    final locationReady =
        _miniMapAvailability == LocationTrackingAvailability.ready;

    return SizedBox(
      height: height,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
            ),
            child: _miniMapLoading
                ? const Center(child: CircularProgressIndicator())
                : !locationReady
                ? _MapUnavailableState(
                    availability: _miniMapAvailability,
                    onEnable: () => unawaited(
                      _initializeMiniMap(requestPermission: true),
                    ),
                    onOpenFullMap: () => unawaited(_openFullMap()),
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
                            _updateMulticameraState(() => _miniMapReady = true);
                            final point = _miniMapCurrent;
                            if (point != null) {
                              _miniMapController.move(
                                LatLng(point.latitude, point.longitude),
                                15.8,
                              );
                            }
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.vigiaia.app',
                            maxNativeZoom: 19,
                          ),
                          if (mapPolyline.length >= 2)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: mapPolyline,
                                  strokeWidth: 4,
                                  color: scheme.primary,
                                ),
                              ],
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
                                      color: scheme.primary.withValues(
                                        alpha: 0.20,
                                      ),
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
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.68),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.map_outlined, size: 16),
                                    SizedBox(width: 8),
                                    Text(
                                      'Mapa do trajeto',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Sua posição em tempo real',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: FilledButton.tonalIcon(
                          onPressed: () => unawaited(_openFullMap()),
                          icon: const Icon(Icons.route_rounded, size: 18),
                          label: const Text('Ver rota completa'),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Column(
                          children: [
                            IconButton.filledTonal(
                              onPressed: () {
                                final point = _miniMapCurrent;
                                if (point == null) return;
                                _miniMapController.move(
                                  LatLng(point.latitude, point.longitude),
                                  15.8,
                                );
                              },
                              icon: const Icon(Icons.my_location_rounded),
                            ),
                            const SizedBox(height: 8),
                            IconButton.filledTonal(
                              onPressed: () {
                                final camera = _miniMapController.camera;
                                _miniMapController.move(
                                  camera.center,
                                  (camera.zoom + 1).clamp(3, 19),
                                );
                              },
                              icon: const Icon(Icons.add_rounded),
                            ),
                            const SizedBox(height: 8),
                            IconButton.filledTonal(
                              onPressed: () {
                                final camera = _miniMapController.camera;
                                _miniMapController.move(
                                  camera.center,
                                  (camera.zoom - 1).clamp(3, 19),
                                );
                              },
                              icon: const Icon(Icons.remove_rounded),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.68),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _miniMapDistanceKm < 1
                                      ? '${(_miniMapDistanceKm * 1000).toStringAsFixed(0)} m'
                                      : '${_miniMapDistanceKm.toStringAsFixed(1)} km',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  bikeSnapshotText(),
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
    );
  }

  String bikeSnapshotText() {
    final bikeSnapshot = _effectiveBikeSnapshot;
    return bikeSnapshot != null
        ? 'Distância pela bike'
        : 'Distância percorrida';
  }

  Widget _buildPortraitActionRow(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        scrollDirection: Axis.horizontal,
        children: [
          SizedBox(
            width: 156,
            child: _DashboardActionButton(
              icon: Icons.radar_rounded,
              label: 'Detectados $_currentDetectionCount',
              onPressed: () => unawaited(_showPortraitDetections()),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 156,
            child: _DashboardActionButton(
              icon: Icons.map_outlined,
              label: 'Mostrar mapa',
              accent: true,
              onPressed: () => unawaited(_openFullMap()),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 132,
            child: _DashboardActionButton(
              icon: _controller.voiceEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              label: 'Áudio',
              onPressed: () =>
                  _controller.setVoiceEnabled(!_controller.voiceEnabled),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 132,
            child: _DashboardActionButton(
              icon: Icons.tune_rounded,
              label: 'Painel',
              onPressed: () => unawaited(_showPortraitQuickPanel()),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 132,
            child: _DashboardActionButton(
              icon: Icons.settings_outlined,
              label: 'Ajustes',
              onPressed: () =>
                  unawaited(_openStandardScreen(const SettingsScreen())),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPortraitQuickPanel() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Painel do monitor',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Atalhos para áreas, filtros, regras, fonte e demais recursos sem ocupar espaço fixo na tela vertical.',
              ),
              const SizedBox(height: 12),
              _buildControlDock(sheetContext, compact: true),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.monitor_heart_outlined),
                title: const Text('Status da sessão'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_showSessionStatus());
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
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPortraitDetections() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.72,
          child: _buildDetectionPanel(sheetContext),
        ),
      ),
    );
  }
}
