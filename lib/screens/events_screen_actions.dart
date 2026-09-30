part of 'events_screen.dart';

extension _EventsActions on _EventsScreenState {
  Future<void> _requestDelete(
    MonitorEvent event, {
    BuildContext? detailContext,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir este registro?'),
        content: const Text(
          'A detecção e seus arquivos de imagem ou vídeo serão apagados. Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (detailContext != null && detailContext.mounted) {
      Navigator.pop(detailContext);
    }
    await _delete(event);
  }

  Future<void> _saveEventMedia(MonitorEvent event) async {
    final path = event.clipPath ?? event.snapshotPath;
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este registro não possui imagem para salvar.'),
        ),
      );
      return;
    }
    final file = File(path);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O arquivo deste registro não está mais disponível.'),
        ),
      );
      return;
    }
    if (!mounted) return;
    final usePicker = await resolveExportLocation(
      context,
      title: 'Salvar captura',
    );
    if (usePicker == null || !mounted) return;
    final extension = path.toLowerCase().endsWith('.mp4')
        ? 'mp4'
        : path.toLowerCase().endsWith('.gif')
        ? 'gif'
        : 'jpg';
    final mimeType = switch (extension) {
      'mp4' => 'video/mp4',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
    final bytes = await file.readAsBytes();
    final savedPath = usePicker
        ? await _native.saveBytesWithPicker(
            fileName: 'VigiaIA-${event.id}.$extension',
            mimeType: mimeType,
            bytes: bytes,
          )
        : await _native.saveBytesToDownloads(
            fileName: 'VigiaIA-${event.id}.$extension',
            mimeType: mimeType,
            bytes: bytes,
          );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          savedPath == null
              ? 'Não foi possível salvar a captura.'
              : 'Captura salva com sucesso.',
        ),
      ),
    );
  }

  void _openEvent(MonitorEvent event) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (event.clipPath != null)
                  _Media(path: event.clipPath!, fit: BoxFit.contain)
                else if (event.snapshotPath != null)
                  _Media(path: event.snapshotPath!, fit: BoxFit.contain)
                else
                  const AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Center(
                      child: Icon(Icons.image_not_supported_outlined, size: 48),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed:
                              event.snapshotPath == null &&
                                  event.clipPath == null
                              ? null
                              : () => unawaited(_saveEventMedia(event)),
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Salvar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => unawaited(
                            _requestDelete(event, detailContext: dialogContext),
                          ),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Excluir'),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _categoryName(event),
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text('Horário: ${_formatDateTime(event.createdAt)}'),
                      Text('Câmera: ${event.source}'),
                      Text('Confiança: ${(event.confidence * 100).round()}%'),
                      if (event.zoneName != null)
                        Text('Área: ${event.zoneName}'),
                      if (event.type != MonitorEventType.alert)
                        Text(
                          event.type == MonitorEventType.entered
                              ? 'Registro: entrada na área (não é contador)'
                              : 'Registro: saída da área (não é contador)',
                        ),
                    ],
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
