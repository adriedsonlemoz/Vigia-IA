import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/offline_map_package.dart';
import '../screens/offline_area_selection_screen.dart';
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
      heightFactor: 0.92,
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
  static const String _stadiaDashboardUrl =
      'https://client.stadiamaps.com/dashboard/';
  static const String _stadiaApiKeyDocsUrl =
      'https://docs.stadiamaps.com/authentication/#api-keys';

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

  Future<void> _openOfficialLink(String url) async {
    final opened = await _native.openExternalUrl(url);
    if (opened || !mounted) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Não foi possível abrir o navegador. O link oficial foi copiado.',
        ),
      ),
    );
  }

  Future<void> _showStadiaKeyHelp() async {
    await showDialog<void>(
      context: context,
      builder: (helpContext) => AlertDialog(
        title: const Text('Como conseguir a API key'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'A chave é fornecida pela Stadia Maps e autoriza o Vigia IA a baixar os tiles permitidos para o mapa offline.',
              ),
              const SizedBox(height: 14),
              const Text(
                'Passo a passo',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                '1. Abra o painel oficial da Stadia Maps.\n'
                '2. Entre na sua conta ou crie uma conta.\n'
                '3. Abra “Manage Properties” e selecione ou crie uma propriedade para o app.\n'
                '4. Em “Authentication Configuration”, gere a API key.\n'
                '5. Copie a chave, volte ao Vigia IA e cole no campo de configuração.',
              ),
              const SizedBox(height: 14),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(helpContext)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Não compartilhe sua chave. O Vigia IA protege a credencial no Android Keystore. Planos, limites e regras de cache são definidos pela Stadia Maps e podem mudar.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Painel oficial:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const SelectableText(
                _stadiaDashboardUrl,
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(helpContext),
            child: const Text('Fechar'),
          ),
          TextButton(
            onPressed: () => unawaited(
              _openOfficialLink(_stadiaApiKeyDocsUrl),
            ),
            child: const Text('Instruções oficiais'),
          ),
          FilledButton.icon(
            onPressed: () => unawaited(
              _openOfficialLink(_stadiaDashboardUrl),
            ),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Abrir painel'),
          ),
        ],
      ),
    );
  }

  Future<void> _configureStadiaKey() async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Fonte para download direto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'O download direto usa tiles raster da Stadia Maps. Você precisa de uma API key da sua própria conta; o Vigia IA protege a chave no Android Keystore.',
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => unawaited(_showStadiaKeyHelp()),
                icon: const Icon(Icons.help_outline_rounded),
                label: const Text('Como conseguir a chave?'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                obscureText: true,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Stadia Maps API key',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'A fonte exige uma assinatura compatível com cache offline. O Vigia IA limita o cache direto a 100 MB por aparelho e mantém a atribuição exigida.',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        actions: [
          if (_service.hasStadiaApiKey)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, ''),
              child: const Text('Remover chave'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    try {
      await _service.configureStadiaApiKey(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isEmpty
                ? 'Chave removida.'
                : 'Chave protegida e salva neste aparelho.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar a chave: $error')),
      );
    }
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
    var radiusKm = 10.0;
    var routeBufferKm = 2.0;
    var maxZoom = 16.0;
    String title;
    String detail;

    switch (kind) {
      case _OfflinePlanKind.current:
        final current = planning.currentPosition;
        if (current == null) {
          _showPlanUnavailable('A posição atual ainda não está disponível.');
          return;
        }
        title = 'Baixar região atual';
        detail = 'Baixa um mapa ao redor da posição atual.';
        baseBounds = _boundsAround(current, radiusKm);
        break;
      case _OfflinePlanKind.visible:
        final initialBounds = planning.visibleBounds;
        final initialCenter = planning.currentPosition ??
            (initialBounds == null
                ? const LatLng(-14.2350, -51.9253)
                : LatLng(
                    (initialBounds.north + initialBounds.south) / 2,
                    (initialBounds.east + initialBounds.west) / 2,
                  ));
        baseBounds = await Navigator.of(context).push<LatLngBounds>(
          MaterialPageRoute<LatLngBounds>(
            builder: (_) => OfflineAreaSelectionScreen(
              initialCenter: initialCenter,
              initialZoom: initialBounds == null ? 13 : 14,
            ),
          ),
        );
        if (baseBounds == null || !mounted) return;
        title = 'Baixar região selecionada';
        detail = 'Usa exatamente o quadro que você posicionou e redimensionou no mapa.';
        break;
      case _OfflinePlanKind.route:
        if (planning.route.length < 2) {
          _showPlanUnavailable('Ainda não existe um trajeto com pontos suficientes.');
          return;
        }
        baseBounds = _routeBounds(planning.route, marginKm: routeBufferKm);
        title = 'Baixar trajeto';
        detail = 'Baixa somente um corredor ao redor do percurso, economizando espaço.';
        break;
    }

    final safeBytes = _service.stadiaSafeAvailableCacheBytes;
    if (safeBytes <= 0) {
      _showPlanUnavailable(
        'O limite seguro do cache direto está ocupado. Exclua um mapa direto antes de baixar outro.',
      );
      return;
    }

    if (kind == _OfflinePlanKind.current) {
      radiusKm = math.min(
        radiusKm,
        _maxRadiusForZoom(planning.currentPosition!, maxZoom.round(), safeBytes),
      ).toDouble();
    } else if (kind == _OfflinePlanKind.route) {
      routeBufferKm = math.min(
        routeBufferKm,
        _maxRouteBufferForZoom(planning.route, maxZoom.round(), safeBytes),
      ).toDouble();
    } else {
      maxZoom = math.min(
        maxZoom,
        _maxZoomForBounds(baseBounds!, safeBytes).toDouble(),
      ).toDouble();
    }

    final nameController = TextEditingController(text: switch (kind) {
      _OfflinePlanKind.current => 'Região atual',
      _OfflinePlanKind.visible => 'Área selecionada',
      _OfflinePlanKind.route => 'Trajeto offline',
    });

    final result = await showDialog<_PlannedDownload>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final bounds = switch (kind) {
            _OfflinePlanKind.current =>
              _boundsAround(planning.currentPosition!, radiusKm),
            _OfflinePlanKind.route =>
              _routeBounds(planning.route, marginKm: routeBufferKm),
            _OfflinePlanKind.visible => baseBounds!,
          };
          final offlineBounds = _toOfflineBounds(bounds);
          final estimate = kind == _OfflinePlanKind.route
              ? _service.estimateRoute(
                  route: planning.route,
                  bufferKm: routeBufferKm,
                  minZoom: 8,
                  maxZoom: maxZoom.round(),
                )
              : _service.estimateBounds(
                  bounds: offlineBounds,
                  minZoom: 8,
                  maxZoom: maxZoom.round(),
                );
          final tooLarge = estimate.bytes > safeBytes;
          final insufficientStorage = _freeStorageBytes != null &&
              estimate.bytes > (_freeStorageBytes! * 0.85);
          final usage = safeBytes <= 0
              ? 1.0
              : (estimate.bytes / safeBytes).clamp(0.0, 1.0).toDouble();
          final nearLimit = !tooLarge && usage >= 0.85;

          final maxRadius = kind == _OfflinePlanKind.current
              ? _maxRadiusForZoom(
                  planning.currentPosition!,
                  13,
                  safeBytes,
                )
              : 50.0;
          final maxRouteBuffer = kind == _OfflinePlanKind.route
              ? _maxRouteBufferForZoom(
                  planning.route,
                  13,
                  safeBytes,
                )
              : 5.0;
          final visibleMaxZoom = kind == _OfflinePlanKind.visible
              ? _maxZoomForBounds(baseBounds!, safeBytes)
              : 17;
          final zoomSliderMax = math.max(13, visibleMaxZoom).toDouble();

          void useMaximumAvailable() {
            setDialogState(() {
              switch (kind) {
                case _OfflinePlanKind.current:
                  radiusKm = _maxRadiusForZoom(
                    planning.currentPosition!,
                    maxZoom.round(),
                    safeBytes,
                  );
                  break;
                case _OfflinePlanKind.route:
                  routeBufferKm = _maxRouteBufferForZoom(
                    planning.route,
                    maxZoom.round(),
                    safeBytes,
                  );
                  break;
                case _OfflinePlanKind.visible:
                  maxZoom = _maxZoomForBounds(baseBounds!, safeBytes).toDouble();
                  break;
              }
            });
          }

          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(detail),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do mapa',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (kind == _OfflinePlanKind.current) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Raio: ${radiusKm.toStringAsFixed(1)} km'),
                        ),
                        Text(
                          'máx. no cache ${maxRadius.toStringAsFixed(1)} km',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                    Slider(
                      value: radiusKm.clamp(1.0, math.max(1.0, maxRadius)).toDouble(),
                      min: 1,
                      max: math.max(1.0, maxRadius).toDouble(),
                      label: '${radiusKm.toStringAsFixed(1)} km',
                      onChanged: maxRadius <= 1
                          ? null
                          : (value) {
                              setDialogState(() {
                                radiusKm = value;
                                final allowedZoom = _maxZoomForBounds(
                                  _boundsAround(planning.currentPosition!, radiusKm),
                                  safeBytes,
                                );
                                if (maxZoom > allowedZoom) {
                                  maxZoom = allowedZoom.toDouble();
                                }
                              });
                            },
                    ),
                  ],
                  if (kind == _OfflinePlanKind.route) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Margem do trajeto: ${routeBufferKm.toStringAsFixed(1)} km',
                          ),
                        ),
                        Text(
                          'máx. no cache ${maxRouteBuffer.toStringAsFixed(1)} km',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                    Slider(
                      value: routeBufferKm.clamp(
                        0.5,
                        math.max(0.5, maxRouteBuffer),
                      ).toDouble(),
                      min: 0.5,
                      max: math.max(0.5, maxRouteBuffer).toDouble(),
                      label: '${routeBufferKm.toStringAsFixed(1)} km',
                      onChanged: maxRouteBuffer <= 0.5
                          ? null
                          : (value) {
                              setDialogState(() {
                                routeBufferKm = value;
                                final allowedZoom = _maxZoomForBounds(
                                  _routeBounds(
                                    planning.route,
                                    marginKm: routeBufferKm,
                                  ),
                                  safeBytes,
                                );
                                if (maxZoom > allowedZoom) {
                                  maxZoom = allowedZoom.toDouble();
                                }
                              });
                            },
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Detalhe: ${_qualityLabel(maxZoom.round())} · zoom ${maxZoom.round()}',
                        ),
                      ),
                      if (kind == _OfflinePlanKind.visible)
                        Text(
                          'máx. z$visibleMaxZoom',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                    ],
                  ),
                  Slider(
                    value: maxZoom.clamp(13.0, zoomSliderMax).toDouble(),
                    min: 13,
                    max: zoomSliderMax,
                    divisions: zoomSliderMax > 13
                        ? (zoomSliderMax - 13).round()
                        : null,
                    label: 'z${maxZoom.round()}',
                    onChanged: zoomSliderMax <= 13
                        ? null
                        : (value) {
                            setDialogState(() {
                              maxZoom = value;
                              if (kind == _OfflinePlanKind.current) {
                                final allowedRadius = _maxRadiusForZoom(
                                  planning.currentPosition!,
                                  maxZoom.round(),
                                  safeBytes,
                                );
                                radiusKm = math.min(radiusKm, allowedRadius).toDouble();
                              } else if (kind == _OfflinePlanKind.route) {
                                final allowedBuffer = _maxRouteBufferForZoom(
                                  planning.route,
                                  maxZoom.round(),
                                  safeBytes,
                                );
                                routeBufferKm = math
                                    .min(routeBufferKm, allowedBuffer)
                                    .toDouble();
                              }
                            });
                          },
                  ),
                  Text(
                    'Os controles se limitam automaticamente ao espaço disponível. Mais detalhe reduz a área máxima e vice-versa.',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: usage),
                  const SizedBox(height: 8),
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
                    icon: Icons.offline_pin_rounded,
                    label: 'Disponível para download',
                    value: _size(safeBytes),
                  ),
                  _PlanMetric(
                    icon: Icons.shield_outlined,
                    label: 'Limite do cache direto',
                    value: '100 MB · reserva de 5 MB',
                  ),
                  _PlanMetric(
                    icon: Icons.phone_android_rounded,
                    label: 'Espaço livre no aparelho',
                    value: _freeStorageBytes == null
                        ? 'Calculando…'
                        : _size(_freeStorageBytes!),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: useMaximumAvailable,
                    icon: const Icon(Icons.auto_fix_high_rounded),
                    label: const Text('Ajustar ao limite disponível'),
                  ),
                  if (!_service.hasStadiaApiKey) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Configure a fonte de download direto antes de iniciar.',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                  if (nearLimit) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Configuração próxima do limite. A reserva de segurança já foi considerada.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.tertiary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  if (tooLarge) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Esta área ainda não cabe no espaço seguro restante. Reduza a seleção ou exclua outro mapa direto.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  if (insufficientStorage) ...[
                    const SizedBox(height: 8),
                    Text(
                      'O espaço livre do aparelho pode não ser suficiente para concluir com segurança.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  const Text(
                    'Fonte direta: Stadia Maps (Alidade Smooth). O app não usa tile.openstreetmap.org para download em massa.',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              if (!_service.hasStadiaApiKey)
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    unawaited(_configureStadiaKey());
                  },
                  child: const Text('Configurar fonte'),
                ),
              FilledButton.icon(
                onPressed: !_service.hasStadiaApiKey || tooLarge || insufficientStorage
                    ? null
                    : () {
                        final name = nameController.text.trim();
                        Navigator.pop(
                          dialogContext,
                          _PlannedDownload(
                            kind: kind,
                            name: name.isEmpty ? title : name,
                            bounds: offlineBounds,
                            route: planning.route,
                            routeBufferKm: routeBufferKm,
                            minZoom: 8,
                            maxZoom: maxZoom.round(),
                          ),
                        );
                      },
                icon: const Icon(Icons.download_rounded),
                label: const Text('Baixar'),
              ),
            ],
          );
        },
      ),
    );
    nameController.dispose();
    if (result == null || !mounted) return;
    await _runPlannedDownload(result);
  }

  Future<void> _runPlannedDownload(_PlannedDownload plan) async {
    if (_service.busy) return;
    try {
      if (plan.kind == _OfflinePlanKind.route) {
        await _service.downloadStadiaRoute(
          displayName: plan.name,
          route: plan.route,
          bufferKm: plan.routeBufferKm,
          minZoom: plan.minZoom,
          maxZoom: plan.maxZoom,
        );
      } else {
        await _service.downloadStadiaRegion(
          displayName: plan.name,
          bounds: plan.bounds,
          minZoom: plan.minZoom,
          maxZoom: plan.maxZoom,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mapa offline baixado e ativado.')),
      );
      unawaited(_loadStorage());
    } catch (error) {
      if (!mounted) return;
      final text = '$error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            text.contains('Download cancelado')
                ? 'Download cancelado.'
                : 'Não foi possível baixar a região: $error',
          ),
        ),
      );
    }
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

  int _maxZoomForBounds(LatLngBounds bounds, int safeBytes) {
    if (safeBytes <= 0) return 13;
    for (var zoom = 17; zoom >= 13; zoom--) {
      final estimate = _service.estimateBounds(
        bounds: _toOfflineBounds(bounds),
        minZoom: 8,
        maxZoom: zoom,
      );
      if (estimate.bytes <= safeBytes) return zoom;
    }
    return 13;
  }

  double _maxRadiusForZoom(
    LatLng center,
    int zoom,
    int safeBytes,
  ) {
    const minRadius = 1.0;
    const maxRadius = 50.0;
    if (safeBytes <= 0) return minRadius;

    bool fits(double radius) => _service
        .estimateBounds(
          bounds: _toOfflineBounds(_boundsAround(center, radius)),
          minZoom: 8,
          maxZoom: zoom,
        )
        .bytes <=
        safeBytes;

    if (!fits(minRadius)) return minRadius;
    if (fits(maxRadius)) return maxRadius;

    var low = minRadius;
    var high = maxRadius;
    for (var i = 0; i < 14; i++) {
      final middle = (low + high) / 2;
      if (fits(middle)) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return math.max(minRadius, (low * 10).floor() / 10);
  }

  double _maxRouteBufferForZoom(
    List<LatLng> route,
    int zoom,
    int safeBytes,
  ) {
    const minBuffer = 0.5;
    const maxBuffer = 5.0;
    if (safeBytes <= 0 || route.length < 2) return minBuffer;

    bool fits(double buffer) => _service
        .estimateRoute(
          route: route,
          bufferKm: buffer,
          minZoom: 8,
          maxZoom: zoom,
        )
        .bytes <=
        safeBytes;

    if (!fits(minBuffer)) return minBuffer;
    if (fits(maxBuffer)) return maxBuffer;

    var low = minBuffer;
    var high = maxBuffer;
    for (var i = 0; i < 12; i++) {
      final middle = (low + high) / 2;
      if (fits(middle)) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return math.max(minBuffer, (low * 10).floor() / 10);
  }

  String _qualityLabel(int zoom) => switch (zoom) {
        <= 13 => 'Básico',
        14 => 'Equilibrado',
        15 => 'Detalhado',
        16 => 'Alto',
        _ => 'Máximo',
      };

  OfflineMapBounds _toOfflineBounds(LatLngBounds bounds) => OfflineMapBounds(
        west: bounds.west,
        south: bounds.south,
        east: bounds.east,
        north: bounds.north,
      );

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
      await _service.downloadPackage(uri: result.uri, displayName: result.name);
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

  Future<void> _update(OfflineMapPackage item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Atualizar mapa offline?'),
        content: const Text(
          'Para respeitar o limite total do cache, a cópia atual será removida antes do novo download. Se a rede falhar, será necessário baixar o mapa novamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Atualizar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _service.updateStadiaPackage(item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mapa atualizado e ativado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível atualizar: $error')),
      );
    }
  }

  Future<void> _delete(OfflineMapPackage item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir mapa offline?'),
        content: Text('“${item.name}” será removido deste aparelho.'),
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
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
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
                        active == null ? 'Nenhum pacote local ativo' : 'Ativo: ${active.name}',
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
                    if (value == 'source') unawaited(_configureStadiaKey());
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'source',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.key_rounded),
                        title: Text('Configurar download direto'),
                      ),
                    ),
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
                        title: Text('Baixar MBTiles por link'),
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
                                  OfflineMapMode.automatic => Icons.swap_calls_rounded,
                                  OfflineMapMode.online => Icons.cloud_outlined,
                                  OfflineMapMode.offline => Icons.offline_pin_outlined,
                                }),
                          enabled: mode != OfflineMapMode.offline || active != null,
                        ),
                      )
                      .toList(growable: false),
                  selected: <OfflineMapMode>{_service.mode},
                  onSelectionChanged: (selection) {
                    if (selection.isNotEmpty) unawaited(_setMode(selection.first));
                  },
                  showSelectedIcon: false,
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    _service.hasStadiaApiKey ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                    color: _service.hasStadiaApiKey ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _service.hasStadiaApiKey
                          ? 'Download direto configurado · ${_size(_service.stadiaCachedBytes)} / 100 MB usados'
                          : 'Download direto ainda não configurado',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton(
                    onPressed: _service.busy ? null : () => unawaited(_configureStadiaKey()),
                    child: Text(_service.hasStadiaApiKey ? 'Alterar' : 'Configurar'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Baixar área', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: _PlanButton(
                        icon: Icons.my_location_rounded,
                        label: 'Região atual',
                        onTap: () => unawaited(_showRegionPlan(_OfflinePlanKind.current)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _PlanButton(
                        icon: Icons.crop_free_rounded,
                        label: 'Selecionar região',
                        onTap: () => unawaited(_showRegionPlan(_OfflinePlanKind.visible)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _PlanButton(
                        icon: Icons.route_rounded,
                        label: 'Trajeto',
                        onTap: () => unawaited(_showRegionPlan(_OfflinePlanKind.route)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
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
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _service.operationLabel ?? 'Processando mapa…',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: _service.progress),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _service.downloadTilesTotal > 0
                              ? '${_service.downloadTilesCompleted}/${_service.downloadTilesTotal} tiles · ${_size(_service.downloadBytes)}'
                              : _service.progress == null
                                  ? _size(_service.downloadBytes)
                                  : '${(_service.progress! * 100).toStringAsFixed(0)}% · ${_size(_service.downloadBytes)}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                      if (_service.canPauseDownload)
                        TextButton.icon(
                          onPressed: _service.downloadPaused
                              ? _service.resumeDownload
                              : () => unawaited(_service.pauseDownload()),
                          icon: Icon(_service.downloadPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                          label: Text(_service.downloadPaused ? 'Continuar' : 'Pausar'),
                        ),
                      TextButton.icon(
                        onPressed: _service.cancelDownload,
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Expanded(
            child: _service.packages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map_outlined, size: 50, color: scheme.onSurfaceVariant),
                          const SizedBox(height: 10),
                          const Text(
                            'Ainda não há mapas offline',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Baixe uma região diretamente, importe um MBTiles ou use um link autorizado.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                    itemCount: _service.packages.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = _service.packages[index];
                      final selected = item.id == _service.activeId;
                      final canUpdate = item.providerId == 'stadia-alidade-smooth' &&
                          item.hasBounds &&
                          item.downloadKind != 'route';
                      final status = item.refreshRecommended
                          ? item.downloadKind == 'route'
                              ? ' · baixe o trajeto novamente'
                              : ' · atualização recomendada'
                          : '';
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: Icon(
                            selected ? Icons.offline_pin_rounded : Icons.map_outlined,
                            color: selected ? scheme.primary : null,
                          ),
                          title: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${_size(item.sizeBytes)}${item.sourceHost == null ? '' : ' · ${item.sourceHost}'}$status',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => unawaited(_service.setActive(item.id)),
                          trailing: PopupMenuButton<String>(
                            enabled: !_service.busy,
                            onSelected: (value) {
                              if (value == 'use') unawaited(_service.setActive(item.id));
                              if (value == 'update') unawaited(_update(item));
                              if (value == 'delete') unawaited(_delete(item));
                            },
                            itemBuilder: (context) => [
                              if (!selected)
                                const PopupMenuItem(value: 'use', child: Text('Usar')),
                              if (canUpdate)
                                const PopupMenuItem(value: 'update', child: Text('Atualizar')),
                              const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
            child: Text(
              _service.mode == OfflineMapMode.automatic
                  ? 'Automático: mapa local como base e internet por cima quando disponível.'
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

class _PlannedDownload {
  const _PlannedDownload({
    required this.kind,
    required this.name,
    required this.bounds,
    required this.route,
    required this.routeBufferKm,
    required this.minZoom,
    required this.maxZoom,
  });

  final _OfflinePlanKind kind;
  final String name;
  final OfflineMapBounds bounds;
  final List<LatLng> route;
  final double routeBufferKm;
  final int minZoom;
  final int maxZoom;
}

class _PlanButton extends StatelessWidget {
  const _PlanButton({required this.icon, required this.label, required this.onTap});

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
  const _PlanMetric({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 17),
          const SizedBox(width: 7),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
