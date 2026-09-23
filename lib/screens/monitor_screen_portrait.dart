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
        final showMap = _shouldShowMonitorMap;
        final width = constraints.maxWidth - 20;
        final calculatedCameraHeight = previewRatio != null && previewRatio > 0
            ? width / previewRatio
            : constraints.maxHeight * 0.32;
        final mapHeight = (constraints.maxHeight * 0.255)
            .clamp(205.0, 270.0)
            .toDouble();
        final baseCameraHeight = horizontalFeed
            ? calculatedCameraHeight.clamp(210.0, 320.0).toDouble()
            : bikeSnapshot == null
            ? (constraints.maxHeight * 0.36).clamp(260.0, 420.0).toDouble()
            : (constraints.maxHeight * 0.31).clamp(220.0, 340.0).toDouble();
        final cameraHeight = showMap
            ? baseCameraHeight
            : (baseCameraHeight + mapHeight * 0.62)
                .clamp(baseCameraHeight, constraints.maxHeight * 0.64)
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
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onDoubleTap: _fullscreenChanging
                            ? null
                            : () => unawaited(_toggleFullscreen()),
                        child: _buildAdaptiveCameraStage(
                          context,
                          portraitEmbedded: true,
                        ),
                      ),
                    ),
                  ),
                  if (showMap) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: _buildPortraitMapCard(
                        context,
                        height: mapHeight,
                      ),
                    ),
                    const SizedBox(height: 7),
                  ] else
                    const SizedBox(height: 7),
                  _buildPortraitActionRow(context),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                    child: _buildPortraitDetectionSummary(context),
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
      height: 64,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(10, 5, 10, 0),
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
    final altitudeMeters = mapCurrent?.altitudeMeters;
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

    return SizedBox(
      height: height,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
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
                          onTap: (_, _) => unawaited(_openFullMap()),
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
                          if (_miniOfflineTileProvider != null)
                            TileLayer(
                              key: ValueKey<String>(
                                'mini-offline-${_miniOfflinePackageId ?? 'active'}',
                              ),
                              tileProvider: _miniOfflineTileProvider,
                              minNativeZoom: _miniOfflineMinZoom,
                              maxNativeZoom: _miniOfflineMaxZoom,
                            ),
                          if (_offlineMaps.mode != OfflineMapMode.offline)
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.vigiaia.app',
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
                        left: 8,
                        top: 8,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.68),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.fromLTRB(8, 4, 8, 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.map_outlined, size: 14),
                                  SizedBox(width: 6),
                                  Text(
                                    'Mapa',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    '• Ao vivo',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => unawaited(_openFullMap()),
                          icon: const Icon(Icons.route_rounded, size: 15),
                          label: const Text('Rota'),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: IconButton.filledTonal(
                                tooltip: 'Minha posição',
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  final point = _miniMapCurrent;
                                  if (point == null) return;
                                  _miniMapController.move(
                                    LatLng(point.latitude, point.longitude),
                                    15.8,
                                  );
                                },
                                icon: const Icon(
                                  Icons.my_location_rounded,
                                  size: 17,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: IconButton.filledTonal(
                                tooltip: 'Aumentar zoom',
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  final camera = _miniMapController.camera;
                                  _miniMapController.move(
                                    camera.center,
                                    (camera.zoom + 1).clamp(3, 19),
                                  );
                                },
                                icon: const Icon(Icons.add_rounded, size: 18),
                              ),
                            ),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: IconButton.filledTonal(
                                tooltip: 'Diminuir zoom',
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  final camera = _miniMapController.camera;
                                  _miniMapController.move(
                                    camera.center,
                                    (camera.zoom - 1).clamp(3, 19),
                                  );
                                },
                                icon: const Icon(Icons.remove_rounded, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (altitudeMeters != null && altitudeMeters.isFinite)
                        Positioned(
                            left: 8,
                            bottom: 8,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.66),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  child: Text(
                                    '${altitudeMeters.round()} m',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
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

  Widget _buildPortraitActionRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SizedBox(
        height: 46,
        child: Row(
          children: [
            Expanded(
              child: _DashboardActionButton(
                icon: Icons.videocam_outlined,
                label: 'Câmera',
                accent: true,
                compact: true,
                onPressed: () => unawaited(_showCameraHub()),
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: _DashboardActionButton(
                icon: _controller.voiceEnabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                label: 'Áudio',
                compact: true,
                onPressed: () =>
                    _controller.setVoiceEnabled(!_controller.voiceEnabled),
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: _DashboardActionButton(
                icon: Icons.tune_rounded,
                label: 'Painel',
                compact: true,
                onPressed: () => unawaited(_showPortraitQuickPanel()),
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: _DashboardActionButton(
                icon: Icons.settings_outlined,
                label: 'Ajustes',
                compact: true,
                onPressed: () =>
                    unawaited(_openStandardScreen(const SettingsScreen())),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortraitDetectionSummary(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tracked = _controller.trackingEnabled;
    final count = tracked
        ? _controller.trackedDetections.length
        : _controller.detections.length;

    String? primaryLabel;
    double? primaryConfidence;
    int? primaryTrackId;

    if (tracked) {
      for (final item in _controller.trackedDetections) {
        final confidence = item.detection.confidence;
        if (primaryConfidence == null || confidence > primaryConfidence) {
          primaryLabel = item.detection.displayLabel;
          primaryConfidence = confidence;
          primaryTrackId = item.trackId;
        }
      }
    } else {
      for (final item in _controller.detections) {
        final confidence = item.confidence;
        if (primaryConfidence == null || confidence > primaryConfidence) {
          primaryLabel = item.displayLabel;
          primaryConfidence = confidence;
        }
      }
    }

    final detail = primaryLabel == null
        ? 'Nenhum objeto no momento'
        : '${primaryTrackId == null ? '' : '#$primaryTrackId · '}$primaryLabel · ${((primaryConfidence ?? 0) * 100).round()}%';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => unawaited(_showPortraitDetections()),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.radar_rounded, color: scheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Detectados',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(width: 7),
                        _CountBadge(count: count),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_up_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonitorMapPreference(BuildContext context) {
    final mode = _mapRoute.monitorVisibility;
    String label(MonitorMapVisibilityMode value) => switch (value) {
          MonitorMapVisibilityMode.automatic => 'Automático',
          MonitorMapVisibilityMode.always => 'Sempre',
          MonitorMapVisibilityMode.hidden => 'Ocultar',
        };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Mapa no Monitor',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 7),
        SegmentedButton<MonitorMapVisibilityMode>(
          segments: MonitorMapVisibilityMode.values
              .map(
                (value) => ButtonSegment<MonitorMapVisibilityMode>(
                  value: value,
                  label: Text(label(value)),
                ),
              )
              .toList(growable: false),
          selected: <MonitorMapVisibilityMode>{mode},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            if (selection.isEmpty) return;
            _miniMapReady = false;
            unawaited(_mapRoute.setMonitorVisibility(selection.first));
          },
        ),
        if (mode == MonitorMapVisibilityMode.automatic) ...[
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'No automático, aparece com Bike, rota ativa ou deslocamento detectado pelo GPS.',
              style: TextStyle(fontSize: 11),
            ),
          ),
        ],
      ],
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
              const SizedBox(height: 12),
              ListenableBuilder(
                listenable: _mapRoute,
                builder: (context, child) => _buildMonitorMapPreference(context),
              ),
              const SizedBox(height: 4),
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: const Text('Abrir mapa completo'),
                subtitle: const Text('GPS, rota e mapas offline'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_openFullMap());
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.60,
          minChildSize: 0.34,
          maxChildSize: 0.90,
          builder: (context, scrollController) => Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: _buildDetectionPanel(
                    context,
                    scrollController: scrollController,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
