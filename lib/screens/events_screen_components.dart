part of 'events_screen.dart';

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.event,
    required this.onOpen,
    required this.onDelete,
  });

  final MonitorEvent event;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 92,
                height: 72,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _EventThumbnail(event: event),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_categoryIcon(event), size: 18, color: scheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _categoryName(event),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(
                          '${(event.confidence * 100).round()}%',
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        _HistoryMeta(
                          icon: Icons.videocam_outlined,
                          text: event.source,
                        ),
                        _HistoryMeta(
                          icon: Icons.schedule_rounded,
                          text: _formatDateTime(event.createdAt),
                        ),
                        if (event.type != MonitorEventType.alert)
                          _HistoryMeta(
                            icon: event.type == MonitorEventType.entered
                                ? Icons.login_rounded
                                : Icons.logout_rounded,
                            text: event.type == MonitorEventType.entered
                                ? 'Entrada · não é contador'
                                : 'Saída · não é contador',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opções',
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'delete', child: Text('Excluir')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryMeta extends StatelessWidget {
  const _HistoryMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      );
}

class _EventThumbnail extends StatelessWidget {
  const _EventThumbnail({required this.event});
  final MonitorEvent event;

  @override
  Widget build(BuildContext context) {
    final path = event.snapshotPath;
    if (path == null || path.isEmpty) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(child: Icon(_categoryIcon(event), size: 32)),
      );
    }
    return _Media(path: path, fit: BoxFit.cover);
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_toggle_off_rounded,
                size: 50,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 10),
              const Text(
                'Nenhuma detecção corresponde aos filtros.\nQuando uma pessoa, automóvel ou animal passar na câmera, o registro aparecerá aqui.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 44),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => unawaited(onRetry()),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
}

class _Media extends StatelessWidget {
  const _Media({required this.path, required this.fit});
  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (path.toLowerCase().endsWith('.mp4')) return _VideoMedia(path: path);
    return Image.file(
      File(path),
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Colors.black26,
        child: Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}

class _VideoMedia extends StatefulWidget {
  const _VideoMedia({required this.path});
  final String path;

  @override
  State<_VideoMedia> createState() => _VideoMediaState();
}

class _VideoMediaState extends State<_VideoMedia> {
  late final VlcPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VlcPlayerController(
      mediaSource: VlcMediaSource(uri: Uri.file(widget.path)),
      autoPlay: true,
      options: const <String>['--no-audio'],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 16 / 9,
        child: VlcPlayer(controller: _controller, fit: VlcVideoFit.contain),
      );
}

String _categoryName(MonitorEvent event) =>
    ObjectFilterCatalog.singularNameForLabel(event.label) ?? 'Detecção';

IconData _categoryIcon(MonitorEvent event) =>
    switch (ObjectFilterCatalog.groupKeyForLabel(event.label)) {
      'person' => Icons.person_outline_rounded,
      'vehicle' => Icons.directions_car_outlined,
      'animal' => Icons.pets_outlined,
      _ => Icons.radar_rounded,
    };

String _formatDateTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} · '
      '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
}
