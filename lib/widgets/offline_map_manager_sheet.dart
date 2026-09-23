import 'dart:async';

import 'package:flutter/material.dart';

import '../models/offline_map_package.dart';
import '../services/offline_map_service.dart';

Future<void> showOfflineMapManager(BuildContext context) async {
  final service = OfflineMapService.instance;
  await service.initialize();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => const FractionallySizedBox(
      heightFactor: 0.82,
      child: _OfflineMapManagerSheet(),
    ),
  );
}

class _OfflineMapManagerSheet extends StatefulWidget {
  const _OfflineMapManagerSheet();

  @override
  State<_OfflineMapManagerSheet> createState() =>
      _OfflineMapManagerSheetState();
}

class _OfflineMapManagerSheetState extends State<_OfflineMapManagerSheet> {
  final OfflineMapService _service = OfflineMapService.instance;

  @override
  void initState() {
    super.initState();
    _service.addListener(_refresh);
  }

  @override
  void dispose() {
    _service.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
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
                FilledButton.tonalIcon(
                  onPressed: _service.busy ? null : _downloadFromLink,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Baixar'),
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
                            'Baixe um arquivo MBTiles de um servidor/provedor que permita mapas offline. O servidor público do OpenStreetMap não é usado para download em massa.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                    itemCount: _service.packages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
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
