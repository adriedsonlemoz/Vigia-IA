import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/route_explorer_models.dart';

class MapPoiDetailsSheet extends StatelessWidget {
  const MapPoiDetailsSheet({
    super.key,
    required this.item,
    required this.icon,
    required this.distanceLabel,
    required this.onNavigate,
    required this.onShowOnMap,
  });

  final RouteExplorerResult item;
  final IconData icon;
  final String distanceLabel;
  final VoidCallback onNavigate;
  final VoidCallback onShowOnMap;

  static Future<void> copyText(
    BuildContext context, {
    required String value,
    required String label,
  }) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copiado.')),
    );
  }

  String get _sourceLabel => item.source == 'offline' ? 'Offline' : 'Online';

  String get _coordinates =>
      '${item.latitude.toStringAsFixed(5)}, ${item.longitude.toStringAsFixed(5)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final details = <_PoiDetailEntry>[
      if (_hasText(item.address))
        _PoiDetailEntry(
          icon: Icons.location_on_outlined,
          label: 'Endereço',
          value: item.address!.trim(),
          copyLabel: 'Endereço',
        ),
      if (_hasText(item.openingHours))
        _PoiDetailEntry(
          icon: Icons.schedule_rounded,
          label: 'Horário',
          value: item.openingHours!.trim(),
        ),
      if (_hasText(item.phone))
        _PoiDetailEntry(
          icon: Icons.phone_outlined,
          label: 'Telefone',
          value: item.phone!.trim(),
          copyLabel: 'Telefone',
        ),
      if (_hasText(item.website))
        _PoiDetailEntry(
          icon: Icons.language_rounded,
          label: 'Site',
          value: item.website!.trim(),
          copyLabel: 'Site',
        ),
      if (_hasText(item.operatorName))
        _PoiDetailEntry(
          icon: Icons.business_outlined,
          label: 'Operador / marca',
          value: item.operatorName!.trim(),
        ),
    ];

    final detailDensity = details.length + item.amenities.length;
    final initialSize = detailDensity == 0
        ? 0.46
        : detailDensity <= 2
            ? 0.58
            : 0.72;
    final minimumSize = detailDensity == 0 ? 0.34 : 0.42;

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: initialSize,
        minChildSize: minimumSize,
        maxChildSize: 0.94,
        builder: (context, scrollController) => Column(
          children: [
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: scheme.primaryContainer,
                        child: Icon(
                          icon,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _InfoPill(
                                  icon: Icons.category_outlined,
                                  text: item.category.label,
                                ),
                                _InfoPill(
                                  icon: Icons.route_outlined,
                                  text: distanceLabel,
                                ),
                                _InfoPill(
                                  icon: item.source == 'offline'
                                      ? Icons.offline_pin_rounded
                                      : Icons.cloud_outlined,
                                  text: _sourceLabel,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (item.subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      item.subtitle.trim(),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Informações do local',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (var index = 0; index < details.length; index++) ...[
                            _PoiDetailTile(entry: details[index]),
                            if (index < details.length - 1)
                              const Divider(height: 1),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (item.amenities.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Comodidades',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final amenity in item.amenities)
                          Chip(
                            avatar: const Icon(Icons.check_circle_outline, size: 17),
                            visualDensity: VisualDensity.compact,
                            label: Text(amenity),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    'Localização',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.my_location_rounded),
                      title: const Text('Coordenadas'),
                      subtitle: Text(_coordinates),
                      trailing: IconButton(
                        tooltip: 'Copiar coordenadas',
                        onPressed: () => copyText(
                          context,
                          value: _coordinates,
                          label: 'Coordenadas',
                        ),
                        icon: const Icon(Icons.copy_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.hasExtraDetails
                        ? 'As informações são fornecidas pela origem do ponto e podem estar incompletas ou desatualizadas.'
                        : 'Este ponto não possui informações adicionais na fonte atual.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  top: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onShowOnMap,
                      icon: const Icon(Icons.map_rounded),
                      label: const Text('Mostrar no mapa'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onNavigate,
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text('Ir até lá'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
}

class _PoiDetailEntry {
  const _PoiDetailEntry({
    required this.icon,
    required this.label,
    required this.value,
    this.copyLabel,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? copyLabel;
}

class _PoiDetailTile extends StatelessWidget {
  const _PoiDetailTile({required this.entry});

  final _PoiDetailEntry entry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(entry.icon),
      title: Text(entry.label),
      subtitle: SelectableText(entry.value),
      trailing: entry.copyLabel == null
          ? null
          : IconButton(
              tooltip: 'Copiar ${entry.label.toLowerCase()}',
              onPressed: () => MapPoiDetailsSheet.copyText(
                context,
                value: entry.value,
                label: entry.copyLabel!,
              ),
              icon: const Icon(Icons.copy_rounded),
            ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: scheme.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(
              text,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
