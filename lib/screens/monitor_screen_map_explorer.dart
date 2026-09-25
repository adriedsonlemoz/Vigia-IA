part of 'monitor_screen.dart';

enum _RouteQuickFilter { all, fuel, food, health, water, nature, travel, other }

extension _MonitorScreenMapExplorer on _MonitorScreenState {
  Widget _mapMonitoringScreen({RouteExplorerResult? focus}) {
    final secondary = _secondaryController;
    return MapMonitoringScreen(
      cameraPreviewBuilder: (_) => _controller.buildPreview(),
      cameraAspectRatio: _controller.previewAspectRatio,
      cameraListenable: _controller,
      cameraAspectRatioProvider: () => _controller.previewAspectRatio,
      externalCameraSourceProvider: (second) => second ? secondary?.sourceConfig : _controller.sourceConfig,
      secondaryCameraPreviewBuilder:
          secondary == null ? null : (_) => secondary.buildPreview(),
      secondaryCameraListenable: secondary,
      secondaryCameraAspectRatioProvider:
          secondary == null ? null : () => secondary.previewAspectRatio,
      bikeApproachStatusProvider: () => _controller.bikeApproachStatus,
      bikeApproachEnabledProvider: () =>
          _controller.bikeModeConfig.enabled &&
          _controller.bikeModeConfig.approachAlertsEnabled,
      initialPointOfInterest: focus,
    );
  }


  Future<void> _showMapExplorerSheet() async {
    await _routeExplorer.initialize();
    if (!mounted) return;
    var filter = _RouteQuickFilter.all;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.88,
            child: ListenableBuilder(
              listenable: _routeExplorer,
              builder: (context, _) {
                final service = _routeExplorer;
                final filtered = service.results.where((item) => _matchesQuickFilter(item, filter)).toList(growable: false);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Próximos pontos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                                SizedBox(height: 2),
                                Text('Locais úteis próximos para consulta rápida.', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Configurações do mapa e percurso',
                            icon: const Icon(Icons.settings_rounded),
                            onPressed: () => unawaited(_showMapExplorerSettings(sheetContext)),
                          ),
                        ],
                      ),
                    ),
                    if (service.loading) const LinearProgressIndicator(minHeight: 2),
                    SizedBox(
                      height: 44,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final item in _RouteQuickFilter.values) ...[
                            ChoiceChip(
                              label: Text(_quickFilterLabel(item)),
                              selected: filter == item,
                              onSelected: (_) => setSheetState(() => filter = item),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _routeExplorerSummary(service),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(sheetContext).textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonalIcon(
                            onPressed: service.loading ? null : () => unawaited(_runMapExplorerSearch(sheetContext, saveAsOffline: false)),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Atualizar'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: service.error != null && service.results.isEmpty
                          ? _buildRouteExplorerEmpty(sheetContext, service.error!)
                          : filtered.isEmpty
                              ? _buildRouteExplorerEmpty(
                                  sheetContext,
                                  service.results.isEmpty ? 'Toque em Atualizar para buscar locais próximos.' : 'Nenhum ponto neste filtro.',
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                                  itemBuilder: (context, index) {
                                    final item = filtered[index];
                                    return Card(
                                      margin: EdgeInsets.zero,
                                      child: ListTile(
                                        leading: CircleAvatar(child: Icon(_mapExplorerCategoryIcon(item.category), size: 19)),
                                        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                        subtitle: Text(item.subtitle.trim().isEmpty ? '${item.category.label} · ${item.source == 'offline' ? 'Offline' : 'Online'}' : '${item.category.label} · ${item.source == 'offline' ? 'Offline' : 'Online'}\n${item.subtitle}', maxLines: 2, overflow: TextOverflow.ellipsis),
                                        trailing: Text(service.formatDistance(item.distanceMeters), style: const TextStyle(fontWeight: FontWeight.w900)),
                                        onTap: () {
                                          Navigator.of(sheetContext).pop();
                                          unawaited(_openFullMap(focus: item));
                                        },
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMapExplorerSettings(BuildContext parentContext) async {
    await showModalBottomSheet<void>(
      context: parentContext,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (settingsContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.92,
          child: ListenableBuilder(
            listenable: _routeExplorer,
            builder: (context, _) {
              final settings = _routeExplorer.settings;
              final mapMode = _mapRoute.monitorVisibility;
              return Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 0, 14, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Configurações do mapa e percurso',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final radius = _compactSettingsGroup(
                              context,
                              title: 'Raio de busca',
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final value in const <int>[5, 10, 20, 50])
                                    _compactChoiceChip(
                                      label: '$value km',
                                      selected: settings.radiusKm == value,
                                      onSelected: () => unawaited(
                                        _routeExplorer.setRadiusKm(value),
                                      ),
                                    ),
                                ],
                              ),
                            );
                            final searchMode = _compactSettingsGroup(
                              context,
                              title: 'Modo de busca',
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _compactChoiceChip(
                                    icon: Icons.my_location_rounded,
                                    label: 'Ao redor',
                                    selected: !settings.searchAheadWhenMoving,
                                    onSelected: () => unawaited(
                                      _routeExplorer
                                          .setSearchAheadWhenMoving(false),
                                    ),
                                  ),
                                  _compactChoiceChip(
                                    icon: Icons.route_rounded,
                                    label: 'No caminho',
                                    selected: settings.searchAheadWhenMoving,
                                    onSelected: () => unawaited(
                                      _routeExplorer
                                          .setSearchAheadWhenMoving(true),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (constraints.maxWidth >= 520) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: radius),
                                  const SizedBox(width: 12),
                                  Expanded(child: searchMode),
                                ],
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                radius,
                                const SizedBox(height: 10),
                                searchMode,
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _settingsTitle('Categorias'),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final category in RouteExplorerCategory.values)
                              FilterChip(
                                avatar: Icon(
                                  _mapExplorerCategoryIcon(category),
                                  size: 15,
                                ),
                                label: Text(_compactCategoryLabel(category)),
                                selected:
                                    settings.categories.contains(category),
                                showCheckmark: false,
                                visualDensity: const VisualDensity(
                                  horizontal: -3,
                                  vertical: -3,
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                labelPadding:
                                    const EdgeInsets.symmetric(horizontal: 1),
                                onSelected: (_) => unawaited(
                                  _routeExplorer.toggleCategory(category),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _settingsTitle('Alertas'),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            FilterChip(
                              avatar: const Icon(
                                Icons.notifications_active_outlined,
                                size: 15,
                              ),
                              label: const Text('Alertas'),
                              selected: settings.alertsEnabled,
                              showCheckmark: false,
                              visualDensity: const VisualDensity(
                                horizontal: -3,
                                vertical: -3,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onSelected: (value) => unawaited(
                                _routeExplorer.setAlertsEnabled(value),
                              ),
                            ),
                            FilterChip(
                              avatar: const Icon(Icons.volume_up_outlined,
                                  size: 15),
                              label: const Text('Voz'),
                              selected: settings.voiceEnabled,
                              showCheckmark: false,
                              visualDensity: const VisualDensity(
                                horizontal: -3,
                                vertical: -3,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onSelected: settings.alertsEnabled
                                  ? (value) => unawaited(
                                        _routeExplorer.setVoiceEnabled(value),
                                      )
                                  : null,
                            ),
                            FilterChip(
                              avatar: const Icon(
                                Icons.phone_android_rounded,
                                size: 15,
                              ),
                              label: const Text('Notificação'),
                              selected: settings.notificationEnabled,
                              showCheckmark: false,
                              visualDensity: const VisualDensity(
                                horizontal: -3,
                                vertical: -3,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onSelected: settings.alertsEnabled
                                  ? (value) => unawaited(
                                        _routeExplorer
                                            .setNotificationEnabled(value),
                                      )
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 7, right: 8),
                              child: Text(
                                'Avisar a',
                                style:
                                    Theme.of(settingsContext).textTheme.bodySmall,
                              ),
                            ),
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final distance in const <int>[
                                    1000,
                                    3000,
                                    5000,
                                    10000,
                                  ])
                                    _compactChoiceChip(
                                      label: distance < 10000
                                          ? '${distance ~/ 1000} km'
                                          : '10 km',
                                      selected: settings.alertDistanceMeters ==
                                          distance,
                                      onSelected: settings.alertsEnabled
                                          ? () => unawaited(
                                                _routeExplorer
                                                    .setAlertDistanceMeters(
                                                  distance,
                                                ),
                                              )
                                          : null,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'O alerta final de aproximação continua em 1 km.',
                          style: Theme.of(settingsContext)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontSize: 10.5),
                        ),
                        const SizedBox(height: 12),
                        _settingsTitle('Uso offline'),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            const gap = 7.0;
                            final width = (constraints.maxWidth - gap) / 2;
                            return Wrap(
                              spacing: gap,
                              runSpacing: gap,
                              children: [
                                SizedBox(
                                  width: width,
                                  child: FilledButton.tonalIcon(
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(0, 40),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 8,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: _routeExplorer.loading
                                        ? null
                                        : () => unawaited(
                                              _runMapExplorerSearch(
                                                settingsContext,
                                                saveAsOffline: true,
                                              ),
                                            ),
                                    icon: const Icon(
                                      Icons.download_for_offline_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Salvar pacote'),
                                  ),
                                ),
                                SizedBox(
                                  width: width,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 40),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 8,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: _routeExplorer.loading
                                        ? null
                                        : () => unawaited(
                                              _runSaveOfflineResults(
                                                settingsContext,
                                              ),
                                            ),
                                    icon: const Icon(Icons.sync_rounded, size: 18),
                                    label: const Text('Atualizar'),
                                  ),
                                ),
                                SizedBox(
                                  width: width,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 40),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 8,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: !_routeExplorer.hasOfflineData
                                        ? null
                                        : () => unawaited(
                                              _confirmDeleteOfflinePoints(
                                                settingsContext,
                                              ),
                                            ),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Excluir pacotes'),
                                  ),
                                ),
                                SizedBox(
                                  width: width,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 40),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 8,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () => unawaited(
                                      _openOfflineMapManager(settingsContext),
                                    ),
                                    icon: const Icon(Icons.map_rounded, size: 18),
                                    label: const Text('Mapas offline'),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _settingsTitle('Mini mapa no monitor'),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _compactChoiceChip(
                              icon: Icons.auto_awesome_rounded,
                              label: 'Automático',
                              selected: mapMode ==
                                  MonitorMapVisibilityMode.automatic,
                              onSelected: () {
                                _miniMapReady = false;
                                unawaited(_mapRoute.setMonitorVisibility(
                                  MonitorMapVisibilityMode.automatic,
                                ));
                              },
                            ),
                            _compactChoiceChip(
                              icon: Icons.map_outlined,
                              label: 'Sempre',
                              selected:
                                  mapMode == MonitorMapVisibilityMode.always,
                              onSelected: () {
                                _miniMapReady = false;
                                unawaited(_mapRoute.setMonitorVisibility(
                                  MonitorMapVisibilityMode.always,
                                ));
                              },
                            ),
                            _compactChoiceChip(
                              icon: Icons.visibility_off_outlined,
                              label: 'Ocultar',
                              selected:
                                  mapMode == MonitorMapVisibilityMode.hidden,
                              onSelected: () {
                                _miniMapReady = false;
                                unawaited(_mapRoute.setMonitorVisibility(
                                  MonitorMapVisibilityMode.hidden,
                                ));
                              },
                            ),
                          ],
                        ),
                        if (mapMode == MonitorMapVisibilityMode.automatic) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Automático mostra o mapa com Bike, gravação de percurso ativa ou deslocamento pelo GPS.',
                            style: Theme.of(settingsContext)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontSize: 10.5),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _compactSettingsGroup(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingsTitle(title),
        child,
      ],
    );
  }

  Widget _compactChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback? onSelected,
    IconData? icon,
  }) {
    return ChoiceChip(
      avatar: icon == null ? null : Icon(icon, size: 15),
      label: Text(label),
      selected: selected,
      showCheckmark: selected && icon == null,
      visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 1),
      onSelected: onSelected == null ? null : (_) => onSelected(),
    );
  }

  String _compactCategoryLabel(RouteExplorerCategory category) =>
      switch (category) {
        RouteExplorerCategory.fuel => 'Postos',
        RouteExplorerCategory.restaurant => 'Restaurantes',
        RouteExplorerCategory.stop => 'Paradas',
        RouteExplorerCategory.workshop => 'Oficinas',
        RouteExplorerCategory.health => 'Saúde',
        RouteExplorerCategory.water => 'Água',
        RouteExplorerCategory.camping => 'Camping',
        RouteExplorerCategory.viewpoint => 'Mirantes',
        RouteExplorerCategory.waterfall => 'Cachoeiras',
        RouteExplorerCategory.market => 'Mercados',
        RouteExplorerCategory.riverBridge => 'Rios/pontes',
      };

  Widget _settingsTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      );

  Widget _buildRouteExplorerEmpty(BuildContext context, String message) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.place_outlined, size: 42), const SizedBox(height: 10), Text(message, textAlign: TextAlign.center)])));

  bool _matchesQuickFilter(RouteExplorerResult item, _RouteQuickFilter filter) => switch (filter) {
    _RouteQuickFilter.all => true,
    _RouteQuickFilter.fuel => item.category == RouteExplorerCategory.fuel,
    _RouteQuickFilter.food => item.category == RouteExplorerCategory.restaurant,
    _RouteQuickFilter.health => item.category == RouteExplorerCategory.health,
    _RouteQuickFilter.water => item.category == RouteExplorerCategory.water,
    _RouteQuickFilter.nature => item.category == RouteExplorerCategory.viewpoint ||
        item.category == RouteExplorerCategory.waterfall ||
        item.category == RouteExplorerCategory.riverBridge,
    _RouteQuickFilter.travel => item.category == RouteExplorerCategory.camping ||
        item.category == RouteExplorerCategory.workshop ||
        item.category == RouteExplorerCategory.market,
    _RouteQuickFilter.other => item.category == RouteExplorerCategory.stop,
  };

  String _quickFilterLabel(_RouteQuickFilter filter) => switch (filter) {
    _RouteQuickFilter.all => 'Todos',
    _RouteQuickFilter.fuel => 'Postos',
    _RouteQuickFilter.food => 'Comida',
    _RouteQuickFilter.health => 'Saúde',
    _RouteQuickFilter.water => 'Água',
    _RouteQuickFilter.nature => 'Natureza',
    _RouteQuickFilter.travel => 'Bike/viagem',
    _RouteQuickFilter.other => 'Outros',
  };

  String _routeExplorerSummary(RouteExplorerService service) {
    if (service.error != null && service.error!.trim().isNotEmpty) return service.error!;
    if (service.results.isEmpty) return service.statusMessage ?? 'Nenhuma busca realizada ainda.';
    final source = service.lastSource == 'offline' ? 'Offline' : 'Online';
    return '${service.results.length} locais · $source${service.resultsUpdatedAt == null ? '' : ' · ${_formatRouteExplorerTimestamp(service.resultsUpdatedAt)}'}';
  }

  Future<void> _confirmDeleteOfflinePoints(BuildContext context) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Excluir pacotes de pontos?'), content: const Text('Todos os pacotes de pontos offline serão removidos. Os mapas MBTiles não serão apagados.'), actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Excluir'))])) ?? false;
    if (!confirmed) return;
    await _routeExplorer.clearOfflineResults();
  }

  Future<void> _runMapExplorerSearch(BuildContext context, {required bool saveAsOffline}) async {
    await _routeExplorer.searchNow(requestPermission: true, saveAsOffline: saveAsOffline);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_routeExplorer.error ?? (saveAsOffline ? 'Busca concluída e pacote offline salvo.' : (_routeExplorer.statusMessage ?? 'Busca concluída.')))));
  }

  Future<void> _runSaveOfflineResults(BuildContext context) async {
    await _routeExplorer.updateActiveOfflinePackage();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_routeExplorer.error ?? _routeExplorer.statusMessage ?? 'Pacote offline salvo.')));
  }

  Future<void> _openOfflineMapManager(BuildContext context) async {
    final current = _miniMapCurrent;
    final route = _mapRoute.route.map((point) => LatLng(point.latitude, point.longitude)).toList(growable: false);
    await showOfflineMapManager(context, planning: OfflineMapPlanningContext(currentPosition: current == null ? null : LatLng(current.latitude, current.longitude), route: route));
  }

  IconData _mapExplorerCategoryIcon(RouteExplorerCategory category) => switch (category) {
    RouteExplorerCategory.fuel => Icons.local_gas_station_rounded,
    RouteExplorerCategory.restaurant => Icons.restaurant_rounded,
    RouteExplorerCategory.stop => Icons.pause_circle_outline_rounded,
    RouteExplorerCategory.workshop => Icons.build_circle_outlined,
    RouteExplorerCategory.health => Icons.local_hospital_outlined,
    RouteExplorerCategory.water => Icons.water_drop_outlined,
    RouteExplorerCategory.camping => Icons.home_outlined,
    RouteExplorerCategory.viewpoint => Icons.visibility_outlined,
    RouteExplorerCategory.waterfall => Icons.water_drop_outlined,
    RouteExplorerCategory.market => Icons.shopping_cart,
    RouteExplorerCategory.riverBridge => Icons.landscape_outlined,
  };

  String _formatRouteExplorerTimestamp(DateTime? dateTime) {
    if (dateTime == null) return 'sem data';
    final local = dateTime.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }
}
