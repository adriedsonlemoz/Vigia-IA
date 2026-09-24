part of 'monitor_screen.dart';

extension _MonitorScreenMapExplorer on _MonitorScreenState {
  Future<void> _showMapExplorerSheet() async {
    await _routeExplorer.initialize();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.92,
          child: ListenableBuilder(
            listenable: _routeExplorer,
            builder: (context, _) {
              final service = _routeExplorer;
              final settings = service.settings;
              final results = service.results;
              final status = service.statusMessage;
              final error = service.error;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mapa e percurso',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Busque locais úteis perto de você, salve uma lista offline e receba avisos por voz ou notificação quando houver ponto importante no caminho.',
                        ),
                        if (service.loading) ...[
                          const SizedBox(height: 12),
                          const LinearProgressIndicator(),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Mini mapa no monitor',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildMonitorMapPreference(sheetContext),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      FilledButton.tonalIcon(
                                        onPressed: () {
                                          Navigator.of(sheetContext).pop();
                                          unawaited(_openFullMap());
                                        },
                                        icon: const Icon(Icons.map_rounded),
                                        label: const Text('Abrir mapa completo'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () => unawaited(
                                          _setMonitorMapVisibilityQuick(
                                            MonitorMapVisibilityMode.always,
                                          ),
                                        ),
                                        icon: const Icon(Icons.visibility_rounded),
                                        label: const Text('Mostrar mapa'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () => unawaited(
                                          _setMonitorMapVisibilityQuick(
                                            MonitorMapVisibilityMode.hidden,
                                          ),
                                        ),
                                        icon: const Icon(Icons.visibility_off_rounded),
                                        label: const Text('Ocultar mapa'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Explorar região',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Raio atual: ${settings.radiusKm} km',
                                    style: Theme.of(sheetContext)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final radius in const <int>[5, 10, 20, 30, 50])
                                        ChoiceChip(
                                          label: Text('$radius km'),
                                          selected: settings.radiusKm == radius,
                                          onSelected: (_) => unawaited(
                                            _routeExplorer.setRadiusKm(radius),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'O que buscar',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final category in RouteExplorerCategory.values)
                                        FilterChip(
                                          avatar: Icon(
                                            _mapExplorerCategoryIcon(category),
                                            size: 18,
                                          ),
                                          label: Text(category.label),
                                          selected: settings.categories.contains(category),
                                          onSelected: (_) => unawaited(
                                            _routeExplorer.toggleCategory(category),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SwitchListTile.adaptive(
                                    value: settings.searchAheadWhenMoving,
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Priorizar o que está à frente'),
                                    subtitle: const Text(
                                      'Quando houver direção de deslocamento, prioriza locais no sentido do percurso.',
                                    ),
                                    onChanged: (value) => unawaited(
                                      _routeExplorer.setSearchAheadWhenMoving(value),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      FilledButton.icon(
                                        onPressed: service.loading
                                            ? null
                                            : () => unawaited(
                                                  _runMapExplorerSearch(
                                                    sheetContext,
                                                    saveAsOffline: false,
                                                  ),
                                                ),
                                        icon: const Icon(Icons.travel_explore_rounded),
                                        label: const Text('Buscar agora'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: service.loading
                                            ? null
                                            : () => unawaited(
                                                  _runSaveOfflineResults(
                                                    sheetContext,
                                                  ),
                                                ),
                                        icon: const Icon(Icons.download_for_offline_rounded),
                                        label: const Text('Salvar lista offline'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Uso offline',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    service.offlineUpdatedAt == null
                                        ? 'Nenhuma lista offline salva ainda.'
                                        : 'Lista salva em ${_formatRouteExplorerTimestamp(service.offlineUpdatedAt)}.',
                                    style: Theme.of(sheetContext)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Você pode baixar o mapa da região e também guardar uma lista local de pontos úteis para usar quando estiver sem internet.',
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => unawaited(
                                          _openOfflineMapManager(sheetContext),
                                        ),
                                        icon: const Icon(Icons.layers_rounded),
                                        label: const Text('Mapas offline'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: service.loading
                                            ? null
                                            : () => unawaited(
                                                  _runMapExplorerSearch(
                                                    sheetContext,
                                                    saveAsOffline: true,
                                                  ),
                                                ),
                                        icon: const Icon(Icons.cloud_download_rounded),
                                        label: const Text('Buscar e salvar'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Alertas no percurso',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SwitchListTile.adaptive(
                                    value: settings.alertsEnabled,
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Avisar automaticamente'),
                                    subtitle: const Text(
                                      'Emite aviso quando um ponto salvo ou buscado estiver se aproximando.',
                                    ),
                                    onChanged: (value) => unawaited(
                                      _routeExplorer.setAlertsEnabled(value),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SwitchListTile.adaptive(
                                          value: settings.voiceEnabled,
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                          title: const Text('Fala'),
                                          onChanged: settings.alertsEnabled
                                              ? (value) => unawaited(
                                                    _routeExplorer.setVoiceEnabled(value),
                                                  )
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: SwitchListTile.adaptive(
                                          value: settings.notificationEnabled,
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                          title: const Text('Notificação'),
                                          onChanged: settings.alertsEnabled
                                              ? (value) => unawaited(
                                                    _routeExplorer.setNotificationEnabled(value),
                                                  )
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Os avisos usam a lista atual da busca. Se estiver sem internet, o app usa a última lista offline salva.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Resultados',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (status != null && status.trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(status),
                                    ),
                                  if (error != null && error.trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        error,
                                        style: TextStyle(
                                          color: Theme.of(sheetContext)
                                              .colorScheme
                                              .error,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    results.isEmpty
                                        ? 'Nenhum local listado ainda.'
                                        : '${results.length} locais encontrados · fonte ${service.lastSource == 'offline' ? 'offline' : 'online'}${service.resultsUpdatedAt == null ? '' : ' · ${_formatRouteExplorerTimestamp(service.resultsUpdatedAt)}'}',
                                    style: Theme.of(sheetContext)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                  const SizedBox(height: 10),
                                  if (results.isEmpty)
                                    const ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.info_outline_rounded),
                                      title: Text('Toque em Buscar agora'),
                                      subtitle: Text(
                                        'A lista vai aparecer aqui com os pontos úteis mais próximos.',
                                      ),
                                    )
                                  else
                                    Column(
                                      children: [
                                        for (final item in results)
                                          ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: CircleAvatar(
                                              child: Icon(
                                                _mapExplorerCategoryIcon(
                                                  item.category,
                                                ),
                                                size: 18,
                                              ),
                                            ),
                                            title: Text(item.title),
                                            subtitle: Text(
                                              '${item.category.label} · ${item.subtitle}\n${service.formatDistance(item.distanceMeters)}',
                                            ),
                                            isThreeLine: true,
                                            trailing: const Icon(
                                              Icons.chevron_right_rounded,
                                            ),
                                            onTap: () {
                                              Navigator.of(sheetContext).pop();
                                              unawaited(_openFullMap());
                                            },
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Future<void> _runMapExplorerSearch(
    BuildContext context, {
    required bool saveAsOffline,
  }) async {
    await _routeExplorer.searchNow(
      requestPermission: true,
      saveAsOffline: saveAsOffline,
    );
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final error = _routeExplorer.error;
    final status = _routeExplorer.statusMessage;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error ??
              (saveAsOffline
                  ? 'Busca concluída e lista salva offline.'
                  : (status ?? 'Busca concluída.')),
        ),
      ),
    );
  }

  Future<void> _runSaveOfflineResults(BuildContext context) async {
    await _routeExplorer.saveCurrentResultsOffline();
    if (!context.mounted) return;
    final error = _routeExplorer.error;
    final status = _routeExplorer.statusMessage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ?? status ?? 'Lista offline atualizada para uso sem internet.',
        ),
      ),
    );
  }

  Future<void> _openOfflineMapManager(BuildContext context) async {
    final current = _miniMapCurrent;
    final route = _mapRoute.route
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);
    await showOfflineMapManager(
      context,
      planning: OfflineMapPlanningContext(
        currentPosition: current == null
            ? null
            : LatLng(current.latitude, current.longitude),
        route: route,
      ),
    );
  }

  IconData _mapExplorerCategoryIcon(RouteExplorerCategory category) {
    switch (category) {
      case RouteExplorerCategory.fuel:
        return Icons.local_gas_station_rounded;
      case RouteExplorerCategory.restaurant:
        return Icons.restaurant_rounded;
      case RouteExplorerCategory.stop:
        return Icons.pause_circle_outline_rounded;
      case RouteExplorerCategory.workshop:
        return Icons.build_circle_outlined;
      case RouteExplorerCategory.health:
        return Icons.local_hospital_outlined;
      case RouteExplorerCategory.water:
        return Icons.water_drop_outlined;
      case RouteExplorerCategory.riverBridge:
        return Icons.landscape_outlined;
    }
  }

  String _formatRouteExplorerTimestamp(DateTime? dateTime) {
    if (dateTime == null) return 'sem data';
    final local = dateTime.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }
}
