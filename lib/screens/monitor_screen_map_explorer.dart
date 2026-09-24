part of 'monitor_screen.dart';

enum _RouteQuickFilter { all, fuel, food, health, water, other }

extension _MonitorScreenMapExplorer on _MonitorScreenState {
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
                                        subtitle: Text('${item.category.label} · ${item.source == 'offline' ? 'Offline' : 'Online'}', maxLines: 1, overflow: TextOverflow.ellipsis),
                                        trailing: Text(service.formatDistance(item.distanceMeters), style: const TextStyle(fontWeight: FontWeight.w900)),
                                        onTap: () {
                                          Navigator.of(sheetContext).pop();
                                          unawaited(_openFullMap());
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
              return Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Configurações do mapa e percurso', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      children: [
                        _settingsTitle('Raio de busca'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [for (final radius in const <int>[5, 10, 20, 50]) ChoiceChip(label: Text('$radius km'), selected: settings.radiusKm == radius, onSelected: (_) => unawaited(_routeExplorer.setRadiusKm(radius)))],
                        ),
                        const SizedBox(height: 16),
                        _settingsTitle('Modo de busca'),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, icon: Icon(Icons.my_location_rounded), label: Text('Ao redor')),
                            ButtonSegment(value: true, icon: Icon(Icons.route_rounded), label: Text('No caminho')),
                          ],
                          selected: {settings.searchAheadWhenMoving},
                          onSelectionChanged: (value) => unawaited(_routeExplorer.setSearchAheadWhenMoving(value.first)),
                        ),
                        const SizedBox(height: 16),
                        _settingsTitle('Categorias'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [for (final category in RouteExplorerCategory.values) FilterChip(avatar: Icon(_mapExplorerCategoryIcon(category), size: 17), label: Text(category.label), selected: settings.categories.contains(category), onSelected: (_) => unawaited(_routeExplorer.toggleCategory(category)))],
                        ),
                        const SizedBox(height: 16),
                        _settingsTitle('Alertas'),
                        SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, value: settings.alertsEnabled, title: const Text('Ativar alertas'), onChanged: (value) => unawaited(_routeExplorer.setAlertsEnabled(value))),
                        Row(
                          children: [
                            Expanded(child: SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, dense: true, value: settings.voiceEnabled, title: const Text('Fala'), onChanged: settings.alertsEnabled ? (value) => unawaited(_routeExplorer.setVoiceEnabled(value)) : null)),
                            const SizedBox(width: 10),
                            Expanded(child: SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, dense: true, value: settings.notificationEnabled, title: const Text('Notificação'), onChanged: settings.alertsEnabled ? (value) => unawaited(_routeExplorer.setNotificationEnabled(value)) : null)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          initialValue: settings.alertDistanceMeters,
                          decoration: const InputDecoration(labelText: 'Distância para aviso'),
                          items: const [
                            DropdownMenuItem(value: 1000, child: Text('1 km')),
                            DropdownMenuItem(value: 3000, child: Text('3 km')),
                            DropdownMenuItem(value: 5000, child: Text('5 km')),
                            DropdownMenuItem(value: 10000, child: Text('10 km')),
                          ],
                          onChanged: (value) { if (value != null) unawaited(_routeExplorer.setAlertDistanceMeters(value)); },
                        ),
                        const SizedBox(height: 6),
                        Text('O aviso configurado é mantido junto do alerta final de aproximação em 1 km.', style: Theme.of(settingsContext).textTheme.bodySmall),
                        const SizedBox(height: 16),
                        _settingsTitle('Uso offline'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonalIcon(onPressed: _routeExplorer.loading ? null : () => unawaited(_runMapExplorerSearch(settingsContext, saveAsOffline: true)), icon: const Icon(Icons.download_for_offline_rounded), label: const Text('Baixar pontos')),
                            OutlinedButton.icon(onPressed: _routeExplorer.loading ? null : () => unawaited(_runSaveOfflineResults(settingsContext)), icon: const Icon(Icons.sync_rounded), label: const Text('Atualizar dados')),
                            OutlinedButton.icon(onPressed: !_routeExplorer.hasOfflineData ? null : () => unawaited(_confirmDeleteOfflinePoints(settingsContext)), icon: const Icon(Icons.delete_outline_rounded), label: const Text('Excluir dados')),
                            OutlinedButton.icon(onPressed: () => unawaited(_openOfflineMapManager(settingsContext)), icon: const Icon(Icons.map_rounded), label: const Text('Mapas offline')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _settingsTitle('Mini mapa'),
                        _buildMonitorMapPreference(settingsContext),
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

  Widget _settingsTitle(String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)));

  Widget _buildRouteExplorerEmpty(BuildContext context, String message) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.place_outlined, size: 42), const SizedBox(height: 10), Text(message, textAlign: TextAlign.center)])));

  bool _matchesQuickFilter(RouteExplorerResult item, _RouteQuickFilter filter) => switch (filter) {
    _RouteQuickFilter.all => true,
    _RouteQuickFilter.fuel => item.category == RouteExplorerCategory.fuel,
    _RouteQuickFilter.food => item.category == RouteExplorerCategory.restaurant,
    _RouteQuickFilter.health => item.category == RouteExplorerCategory.health,
    _RouteQuickFilter.water => item.category == RouteExplorerCategory.water,
    _RouteQuickFilter.other => item.category == RouteExplorerCategory.stop || item.category == RouteExplorerCategory.workshop || item.category == RouteExplorerCategory.riverBridge,
  };

  String _quickFilterLabel(_RouteQuickFilter filter) => switch (filter) {
    _RouteQuickFilter.all => 'Todos',
    _RouteQuickFilter.fuel => 'Postos',
    _RouteQuickFilter.food => 'Comida',
    _RouteQuickFilter.health => 'Saúde',
    _RouteQuickFilter.water => 'Água',
    _RouteQuickFilter.other => 'Outros',
  };

  String _routeExplorerSummary(RouteExplorerService service) {
    if (service.error != null && service.error!.trim().isNotEmpty) return service.error!;
    if (service.results.isEmpty) return service.statusMessage ?? 'Nenhuma busca realizada ainda.';
    final source = service.lastSource == 'offline' ? 'Offline' : 'Online';
    return '${service.results.length} locais · $source${service.resultsUpdatedAt == null ? '' : ' · ${_formatRouteExplorerTimestamp(service.resultsUpdatedAt)}'}';
  }

  Future<void> _confirmDeleteOfflinePoints(BuildContext context) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Excluir dados offline?'), content: const Text('A lista de pontos salva será removida. Os mapas offline não serão apagados.'), actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Excluir'))])) ?? false;
    if (!confirmed) return;
    await _routeExplorer.clearOfflineResults();
  }

  Future<void> _runMapExplorerSearch(BuildContext context, {required bool saveAsOffline}) async {
    await _routeExplorer.searchNow(requestPermission: true, saveAsOffline: saveAsOffline);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_routeExplorer.error ?? (saveAsOffline ? 'Busca concluída e lista salva offline.' : (_routeExplorer.statusMessage ?? 'Busca concluída.')))));
  }

  Future<void> _runSaveOfflineResults(BuildContext context) async {
    await _routeExplorer.saveCurrentResultsOffline();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_routeExplorer.error ?? _routeExplorer.statusMessage ?? 'Lista offline atualizada.')));
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
    RouteExplorerCategory.riverBridge => Icons.landscape_outlined,
  };

  String _formatRouteExplorerTimestamp(DateTime? dateTime) {
    if (dateTime == null) return 'sem data';
    final local = dateTime.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }
}
