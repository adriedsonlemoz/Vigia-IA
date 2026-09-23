import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/offline_map_package.dart';
import '../services/native_platform_service.dart';
import '../services/offline_map_service.dart';

class OfflineMapPlanningContext {
  const OfflineMapPlanningContext({
    this.currentPosition,
    this.visibleBounds,
    this.route = const <LatLng>[],
  });

  final LatLng? currentPosition;
  final LatLngBounds? visibleBounds;
  final List<LatLng> route;
}

Future<void> showOfflineMapManager(
  BuildContext context, {
  OfflineMapPlanningContext planning = const OfflineMapPlanningContext(),
}) async {
  final service = OfflineMapService.instance;
  await service.initialize();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: 0.90,
      child: _OfflineMapManagerSheet(planning: planning),
    ),
  );
}

class _OfflineMapManagerSheet extends StatefulWidget {
  const _OfflineMapManagerSheet({required this.planning});

  final OfflineMapPlanningContext planning;

  @override
  State<_OfflineMapManagerSheet> createState() =>
      _OfflineMapManagerSheetState();
}

class _OfflineMapManagerSheetState extends State<_OfflineMapManagerSheet> {
  final OfflineMapService _service = OfflineMapService.instance;
  final NativePlatformService _native = NativePlatformService.instance;
  int? _freeStorageBytes;

  @override
  void initState() {
    super.initState();
    _service.addListener(_refresh);
    unawaited(_loadStorage());
  }

  @override
  void dispose() {
    _service.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadStorage() async {
    final telemetry = await _native.readDeviceTelemetry();
    if (!mounted) return;
    setState(() => _freeStorageBytes = telemetry.freeStorageBytes);
  }

  Future<void> _importFromDevice() async {
    if (_service.busy) return;
    final picked = await _native.pickOfflineMapPackage();
    if (picked == null || !mounted) return;
    try {
      await _service.importPackage(
        sourcePath: picked.path,
        displayName: picked.name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mapa MBTiles importado e ativado.')),
      );
      unawaited(_loadStorage());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível importar o mapa: $error')),
      );
    }
  }

  Future<void> _showRegionPlan(_OfflinePlanKind kind) async {
    final planning = widget.planning;
    LatLngBounds? baseBounds;
    String title;
    String detail;
    var radiusKm = 10.0;

    switch (kind) {
      case _OfflinePlanKind.current:
        final current = planning.currentPosition;
        if (current == null) {
          _showPlanUnavailable('A posição atual ainda não está disponível.');
          return;
        }
        title = 'Baixar região atual';
        detail = 'Área ao redor da sua posição atual.';
        baseBounds = _boundsAround(current, radiusKm);
        break;
      case _OfflinePlanKind.visible:
        baseBounds = planning.visibleBounds;
        if (baseBounds == null) {
          _showPlanUnavailable('Abra o mapa e enquadre a região desejada antes de planejar o download.');
          return;
        }
        title = 'Selecionar região';
        detail = 'Usa a área que estava visível no mapa quando este painel foi aberto.';
        break;
      case _OfflinePlanKind.route:
        if (planning.route.length < 2) {
          _showPlanUnavailable('Ainda não existe um trajeto com pontos suficientes.');
          return;
        }
        baseBounds = _routeBounds(planning.route, marginKm: 2);
        title = 'Baixar trajeto';
        detail = 'Corredor aproximado em torno do trajeto salvo.';
        break;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final bounds = kind == _OfflinePlanKind.current
              ? _boundsAround(planning.currentPosition!, radiusKm)
              : baseBounds!;
          final estimate = _estimate(bounds);
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(detail),
                  if (kind == _OfflinePlanKind.current) ...[
                    const SizedBox(height: 14),
                    Text('Raio: ${radiusKm.toStringAsFixed(0)} km'),
                    Slider(
                      value: radiusKm,
                      min: 5,
                      max: 50,
                      divisions: 9,
                      label: '${radiusKm.toStringAsFixed(0)} km',
                      onChanged: (value) =>
                          setDialogState(() => radiusKm = value),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _PlanMetric(
                    icon: Icons.grid_view_rounded,
                    label: 'Tiles estimados',
                    value: _compactNumber(estimate.tiles),
                  ),
                  _PlanMetric(
                    icon: Icons.sd_storage_outlined,
                    label: 'Tamanho estimado',
                    value: '~${_size(estimate.bytes)}',
                  ),
                  _PlanMetric(
                    icon: Icons.phone_android_rounded,
                    label: 'Espaço livre',
                    value: _freeStorageBytes == null
                        ? 'Calculando…'
                        : _size(_freeStorageBytes!),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Estimativa para zoom 8–16 e tiles raster médios. O tamanho real do MBTiles depende do provedor, compressão e níveis de zoom.',
                    style: TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'O Vigia IA não baixa em massa do tile.openstreetmap.org. Use um pacote de fonte autorizada ou importe um MBTiles já gerado.',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Fechar'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  unawaited(_importFromDevice());
                },
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Importar'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  unawaited(_downloadFromLink());
                },
                icon: const Icon(Icons.link_rounded),
                label: const Text('Usar link'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPlanUnavailable(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  LatLngBounds _boundsAround(LatLng center, double radiusKm) {
    final latDelta = radiusKm / 111.0;
    final cosLat = math
        .cos(center.latitude * math.pi / 180)
        .abs()
        .clamp(0.15, 1.0)
        .toDouble();
    final lonDelta = radiusKm / (111.0 * cosLat);
    return LatLngBounds(
      LatLng(center.latitude - latDelta, center.longitude - lonDelta),
      LatLng(center.latitude + latDelta, center.longitude + lonDelta),
    );
  }

  LatLngBounds _routeBounds(List<LatLng> route, {required double marginKm}) {
    var minLat = route.first.latitude;
    var maxLat = route.first.latitude;
    var minLon = route.first.longitude;
    var maxLon = route.first.longitude;
    for (final point in route.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLon = math.min(minLon, point.longitude);
      maxLon = math.max(maxLon, point.longitude);
    }
    final center = LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);
    final margin = _boundsAround(center, marginKm);
    final latMargin = (margin.north - margin.south) / 2;
    final lonMargin = (margin.east - margin.west) / 2;
    return LatLngBounds(
      LatLng(minLat - latMargin, minLon - lonMargin),
      LatLng(maxLat + latMargin, maxLon + lonMargin),
    );
  }

  ({int tiles, int bytes}) _estimate(LatLngBounds bounds) {
    var tiles = 0;
    for (var zoom = 8; zoom <= 16; zoom++) {
      final n = 1 << zoom;
      int x(double lon) =>
          (((lon + 180) / 360) * n).floor().clamp(0, n - 1).toInt();
      int y(double lat) {
        final safe = lat.clamp(-85.05112878, 85.05112878).toDouble();
        final rad = safe * math.pi / 180;
        final value = (1 - math.log(math.tan(rad) + 1 / math.cos(rad)) / math.pi) / 2 * n;
        return value.floor().clamp(0, n - 1).toInt();
      }
      final x1 = x(bounds.west);
      final x2 = x(bounds.east);
      final y1 = y(bounds.north);
      final y2 = y(bounds.south);
      final width = ((x2 - x1).abs() + 1).clamp(1, n).toInt();
      final height = ((y2 - y1).abs() + 1).clamp(1, n).toInt();
      tiles += width * height;
    }
    tiles = math.max(1, tiles).toInt();
    const averageTileBytes = 24 * 1024;
    return (tiles: tiles, bytes: tiles * averageTileBytes);
  }

  String _compactNumber(int value) {
    if (value < 1000) return '$value';
    if (value < 1000000) return '${(value / 1000).toStringAsFixed(1)} mil';
    return '${(value / 1000000).toStringAsFixed(1)} mi';
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(2)} GB';
  }

  String _modeLabel(OfflineMapMode mode) => switch (mode) {
        OfflineMapMode.automatic => 'Auto',
        OfflineMapMode.online => 'Online',
        OfflineMapMode.offline => 'Offline',
      };

  Future<void> _downloadFromLink() async {
    if (_service.busy) return;
    final urlController = TextEditingController();
    final nameController = TextEditingController();
    final result = await showDialog<({Uri uri, String? name})>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Baixar pacote MBTiles'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Cole um link direto para um arquivo .mbtiles de uma fonte que permita uso offline.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: urlController,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Link do pacote',
                  hintText: 'https://servidor/mapa.mbtiles',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome (opcional)',
                  hintText: 'Ex.: Centro e região',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final uri = Uri.tryParse(urlController.text.trim());
              if (uri == null ||
                  (uri.scheme != 'http' && uri.scheme != 'https') ||
                  uri.host.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Informe um link HTTP/HTTPS válido.')),
                );
                return;
              }
              final name = nameController.text.trim();
              Navigator.pop(
                dialogContext,
                (uri: uri, name: name.isEmpty ? null : name),
              );
            },
            child: const Text('Baixar'),
          ),
        ],
      ),
    );
    urlController.dispose();
    nameController.dispose();
    if (result == null || !mounted) return;

    try {
      await _service.downloadPackage(
        uri: result.uri,
        displayName: result.name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mapa offline baixado e ativado.')),
      );
      unawaited(_loadStorage());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível baixar o mapa: $error')),
      );
    }
  }

  Future<void> _setMode(OfflineMapMode mode) async {
    try {
      await _service.setMode(mode);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _delete(OfflineMapPackage item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir mapa offline?'),
        content: Text(
          '“${item.name}” será removido do armazenamento deste aparelho.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _service.deletePackage(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = _service.activePackage;
    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mapas offline',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        active == null
                            ? 'Nenhum pacote local ativo'
                            : 'Ativo: ${active.name}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Adicionar mapa offline',
                  enabled: !_service.busy,
                  onSelected: (value) {
                    if (value == 'import') unawaited(_importFromDevice());
                    if (value == 'link') unawaited(_downloadFromLink());
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'import',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.folder_open_rounded),
                        title: Text('Importar MBTiles'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'link',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.link_rounded),
                        title: Text('Baixar por link'),
                      ),
                    ),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded),
                        SizedBox(width: 4),
                        Text('Adicionar'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 390;
                return SegmentedButton<OfflineMapMode>(
                  segments: OfflineMapMode.values
                      .map(
                        (mode) => ButtonSegment<OfflineMapMode>(
                          value: mode,
                          label: Text(_modeLabel(mode)),
                          icon: compact
                              ? null
                              : Icon(switch (mode) {
                                  OfflineMapMode.automatic =>
                                    Icons.swap_calls_rounded,
                                  OfflineMapMode.online => Icons.cloud_outlined,
                                  OfflineMapMode.offline =>
                                    Icons.offline_pin_outlined,
                                }),
                          enabled:
                              mode != OfflineMapMode.offline || active != null,
                        ),
                      )
                      .toList(growable: false),
                  selected: <OfflineMapMode>{_service.mode},
                  onSelectionChanged: (selection) {
                    if (selection.isNotEmpty) {
                      unawaited(_setMode(selection.first));
                    }
                  },
                  showSelectedIcon: false,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Preparar mapa offline',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: _PlanButton(
                        icon: Icons.my_location_rounded,
                        label: 'Região atual',
                        onTap: () => unawaited(
                          _showRegionPlan(_OfflinePlanKind.current),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _PlanButton(
                        icon: Icons.crop_free_rounded,
                        label: 'Selecionar região',
                        onTap: () => unawaited(
                          _showRegionPlan(_OfflinePlanKind.visible),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _PlanButton(
                        icon: Icons.route_rounded,
                        label: 'Trajeto',
                        onTap: () => unawaited(
                          _showRegionPlan(_OfflinePlanKind.route),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _freeStorageBytes == null
                      ? 'Espaço livre: calculando…'
                      : 'Espaço livre: ${_size(_freeStorageBytes!)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          if (_service.busy) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _service.operationLabel ?? 'Processando mapa…',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 7),
                  LinearProgressIndicator(value: _service.progress),
                  if (_service.progress != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${(_service.progress! * 100).toStringAsFixed(0)}%',
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: _service.packages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.map_outlined,
                            size: 52,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Ainda não há mapas baixados',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Importe um MBTiles do aparelho ou use um link direto de um servidor/provedor que permita mapas offline. O servidor público do OpenStreetMap não é usado para download em massa.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                    itemCount: _service.packages.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = _service.packages[index];
                      final selected = item.id == _service.activeId;
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: Icon(
                            selected
                                ? Icons.offline_pin_rounded
                                : Icons.map_outlined,
                            color: selected ? scheme.primary : null,
                          ),
                          title: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${_size(item.sizeBytes)}${item.sourceHost == null ? '' : ' · ${item.sourceHost}'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => unawaited(_service.setActive(item.id)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!selected)
                                TextButton(
                                  onPressed: () =>
                                      unawaited(_service.setActive(item.id)),
                                  child: const Text('Usar'),
                                ),
                              IconButton(
                                tooltip: 'Excluir',
                                onPressed: _service.busy
                                    ? null
                                    : () => unawaited(_delete(item)),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
            child: Text(
              _service.mode == OfflineMapMode.automatic
                  ? 'Automático: o pacote local fica por baixo e a camada online atualiza os tiles quando houver rede.'
                  : _service.mode == OfflineMapMode.offline
                      ? 'Offline: somente o pacote MBTiles ativo é usado.'
                      : 'Online: usa somente o mapa da internet.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}


enum _OfflinePlanKind { current, visible, route }

class _PlanButton extends StatelessWidget {
  const _PlanButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        visualDensity: VisualDensity.compact,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _PlanMetric extends StatelessWidget {
  const _PlanMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      );
}
