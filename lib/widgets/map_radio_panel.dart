import 'dart:async';

import 'package:flutter/material.dart';

import '../services/map_radio_service.dart';
import '../services/map_ride_settings_service.dart';
import '../services/radio_browser_service.dart';

enum _RadioSection { discover, favorites, manual }

class MapRadioPanel extends StatefulWidget {
  const MapRadioPanel({
    super.key,
    required this.settings,
    required this.onPlaybackStateChanged,
  });

  final MapRideSettingsService settings;
  final ValueChanged<String> onPlaybackStateChanged;

  @override
  State<MapRadioPanel> createState() => _MapRadioPanelState();
}

class _MapRadioPanelState extends State<MapRadioPanel> {
  final _catalog = RadioBrowserService();
  final _queryController = TextEditingController();
  final _manualNameController = TextEditingController();
  final _manualUrlController = TextEditingController();
  List<RadioBrowserStation> _results = const <RadioBrowserStation>[];
  _RadioSection _section = _RadioSection.discover;
  bool _brazilOnly = true;
  bool _loading = false;
  String? _error;
  String _playbackState = 'parado';
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshPlayback());
    unawaited(_search());
    _statusTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_refreshPlayback()),
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _catalog.dispose();
    _queryController.dispose();
    _manualNameController.dispose();
    _manualUrlController.dispose();
    super.dispose();
  }

  List<RadioBrowserStation> get _favorites => widget.settings.stations
      .map(RadioBrowserStation.fromSavedMap)
      .where((station) => station.streamUrl.isNotEmpty)
      .toList(growable: false);

  RadioBrowserStation? get _selected {
    final url = widget.settings.radioUrl;
    if (url.isEmpty) return null;
    for (final station in <RadioBrowserStation>[..._favorites, ..._results]) {
      if (station.streamUrl == url) return station;
    }
    return RadioBrowserStation(
      id: '',
      name: widget.settings.radioName.isEmpty
          ? 'Rádio online'
          : widget.settings.radioName,
      streamUrl: url,
      faviconUrl: '',
      country: '',
      state: '',
      language: '',
      tags: '',
      codec: '',
      bitrate: 0,
      votes: 0,
    );
  }

  Future<void> _refreshPlayback() async {
    try {
      final status = await MapRadioService.statusDetails();
      if (!mounted) return;
      if (_playbackState != status.state) {
        setState(() => _playbackState = status.state);
        widget.onPlaybackStateChanged(status.state);
      }
    } catch (_) {}
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _catalog.search(
        query: _queryController.text,
        brazilOnly: _brazilOnly,
      );
      if (!mounted) return;
      setState(() => _results = results);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('HttpException: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isFavorite(RadioBrowserStation station) => widget.settings.stations
      .any((item) => item['url'] == station.streamUrl);

  Future<void> _toggleFavorite(RadioBrowserStation station) async {
    final saved = <Map<String, String>>[...widget.settings.stations];
    if (_isFavorite(station)) {
      saved.removeWhere((item) => item['url'] == station.streamUrl);
    } else {
      saved.add(station.toSavedMap());
    }
    await widget.settings.update(savedStations: saved);
    if (mounted) setState(() {});
  }

  Future<void> _play(RadioBrowserStation station) async {
    try {
      await widget.settings.update(
        stationName: station.name,
        stationUrl: station.streamUrl,
      );
      await MapRadioService.play(
        name: station.name,
        url: station.streamUrl,
        volume: widget.settings.radioVolume,
      );
      if (!mounted) return;
      setState(() => _playbackState = 'conectando');
      widget.onPlaybackStateChanged('conectando');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _refreshPlayback();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rádio indisponível: $error')),
      );
    }
  }

  Future<void> _pauseOrResume() async {
    if (_playbackState == 'tocando' || _playbackState == 'conectando') {
      await MapRadioService.pause();
    } else if (_playbackState == 'pausado') {
      await MapRadioService.resume();
    } else if (_selected != null) {
      await _play(_selected!);
      return;
    }
    await _refreshPlayback();
  }

  Future<void> _stop() async {
    await MapRadioService.stop();
    await _refreshPlayback();
  }

  void _skip(int offset) {
    final stations = _favorites.isNotEmpty ? _favorites : _results;
    if (stations.isEmpty) return;
    final current = stations.indexWhere(
      (station) => station.streamUrl == widget.settings.radioUrl,
    );
    final index = (current < 0 ? 0 : current + offset) % stations.length;
    unawaited(_play(stations[index]));
  }

  Future<void> _saveManual({bool playNow = false}) async {
    final name = _manualNameController.text.trim();
    final url = _manualUrlController.text.trim();
    final uri = Uri.tryParse(url);
    if (name.isEmpty || uri == null ||
        !<String>{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe nome e URL HTTP(S) direta do áudio.')),
      );
      return;
    }
    final station = RadioBrowserStation(
      id: '',
      name: name,
      streamUrl: uri.toString(),
      faviconUrl: '',
      country: '',
      state: '',
      language: '',
      tags: '',
      codec: '',
      bitrate: 0,
      votes: 0,
    );
    final saved = <Map<String, String>>[
      ...widget.settings.stations.where((item) => item['url'] != station.streamUrl),
      station.toSavedMap(),
    ];
    await widget.settings.update(
      savedStations: saved,
      stationName: station.name,
      stationUrl: station.streamUrl,
    );
    _manualNameController.clear();
    _manualUrlController.clear();
    if (playNow) await _play(station);
    if (mounted) setState(() => _section = _RadioSection.favorites);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 8, 4),
          child: Row(
            children: [
              Icon(Icons.radio_rounded, color: scheme.primary),
              const SizedBox(width: 9),
              const Expanded(
                child: Text('Rádio online',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              ),
              IconButton(
                tooltip: 'Fechar',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        _buildPlayer(scheme),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: SegmentedButton<_RadioSection>(
            segments: const [
              ButtonSegment(value: _RadioSection.discover,
                  icon: Icon(Icons.travel_explore_rounded), label: Text('Buscar')),
              ButtonSegment(value: _RadioSection.favorites,
                  icon: Icon(Icons.star_rounded), label: Text('Favoritas')),
              ButtonSegment(value: _RadioSection.manual,
                  icon: Icon(Icons.link_rounded), label: Text('URL')),
            ],
            selected: <_RadioSection>{_section},
            showSelectedIcon: false,
            onSelectionChanged: (value) => setState(() => _section = value.first),
          ),
        ),
        Expanded(child: switch (_section) {
          _RadioSection.discover => _buildDiscovery(),
          _RadioSection.favorites => _buildFavorites(),
          _RadioSection.manual => _buildManual(),
        }),
      ],
    );
  }

  Widget _buildPlayer(ColorScheme scheme) {
    final station = _selected;
    final active = _playbackState == 'tocando' ||
        _playbackState == 'conectando' || _playbackState == 'pausado';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _StationLogo(station: station, size: 50),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(station?.name ?? 'Nenhuma rádio selecionada',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text(station?.location ?? 'Busque uma estação para começar',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(_playbackLabel,
                        style: TextStyle(color: active ? scheme.primary : null,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              if (station != null)
                IconButton(
                  tooltip: _isFavorite(station) ? 'Remover favorita' : 'Favoritar',
                  onPressed: () => unawaited(_toggleFavorite(station)),
                  icon: Icon(_isFavorite(station)
                      ? Icons.star_rounded : Icons.star_border_rounded),
                ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(tooltip: 'Anterior', onPressed: () => _skip(-1),
                  icon: const Icon(Icons.skip_previous_rounded)),
              FilledButton.tonalIcon(
                onPressed: station == null ? null : () => unawaited(_pauseOrResume()),
                icon: Icon(_playbackState == 'tocando' || _playbackState == 'conectando'
                    ? Icons.pause_rounded : Icons.play_arrow_rounded),
                label: Text(_playbackState == 'pausado' ? 'Continuar'
                    : _playbackState == 'tocando' ? 'Pausar' : 'Tocar'),
              ),
              IconButton(tooltip: 'Próxima', onPressed: () => _skip(1),
                  icon: const Icon(Icons.skip_next_rounded)),
              IconButton(tooltip: 'Parar', onPressed: active ? () => unawaited(_stop()) : null,
                  icon: const Icon(Icons.stop_rounded)),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.volume_down_rounded, size: 19),
              Expanded(
                child: Slider(
                  value: widget.settings.radioVolume,
                  onChanged: (value) {
                    setState(() {});
                    unawaited(widget.settings.update(radioVolume: value));
                    unawaited(MapRadioService.setVolume(value));
                  },
                ),
              ),
              const Icon(Icons.volume_up_rounded, size: 19),
            ],
          ),
        ],
      ),
    );
  }

  String get _playbackLabel => switch (_playbackState) {
        'tocando' => 'Ao vivo',
        'conectando' => 'Conectando…',
        'pausado' => 'Pausada',
        'indisponível' => 'Stream indisponível',
        _ => 'Parada',
      };

  Widget _buildDiscovery() => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Nome da rádio',
                      prefixIcon: Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                    onSubmitted: (_) => unawaited(_search()),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: 'Buscar rádios',
                  onPressed: _loading ? null : () => unawaited(_search()),
                  icon: const Icon(Icons.search_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                FilterChip(
                  selected: _brazilOnly,
                  label: const Text('Brasil'),
                  avatar: const Icon(Icons.flag_rounded, size: 17),
                  onSelected: (value) {
                    setState(() => _brazilOnly = value);
                    unawaited(_search());
                  },
                ),
                const SizedBox(width: 8),
                Text(_brazilOnly ? 'Estações brasileiras' : 'Catálogo mundial'),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _error != null
                ? _RadioMessage(message: _error!, action: _search)
                : _results.isEmpty && !_loading
                    ? const _RadioMessage(message: 'Nenhuma estação encontrada.')
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                        itemCount: _results.length,
                        itemBuilder: (context, index) =>
                            _stationTile(_results[index]),
                      ),
          ),
        ],
      );

  Widget _buildFavorites() {
    final favorites = _favorites;
    if (favorites.isEmpty) {
      return const _RadioMessage(
        message: 'Suas rádios favoritas aparecerão aqui para acesso rápido.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      itemCount: favorites.length,
      itemBuilder: (context, index) => _stationTile(favorites[index]),
    );
  }

  Widget _buildManual() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        children: [
          const Text('Adicionar stream direto',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Use uma URL HTTP(S) de áudio, não o endereço da página da rádio.'),
          const SizedBox(height: 12),
          TextField(controller: _manualNameController,
              decoration: const InputDecoration(labelText: 'Nome da estação')),
          const SizedBox(height: 10),
          TextField(controller: _manualUrlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'URL direta do stream')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => unawaited(_saveManual()),
                icon: const Icon(Icons.star_border_rounded),
                label: const Text('Salvar'),
              )),
              const SizedBox(width: 8),
              Expanded(child: FilledButton.icon(
                onPressed: () => unawaited(_saveManual(playNow: true)),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Salvar e tocar'),
              )),
            ],
          ),
          const SizedBox(height: 12),
          const Text('O catálogo Radio Browser é público e não exige chave de API. A reprodução usa internet e ocorre diretamente do servidor da estação.'),
        ],
      );

  Widget _stationTile(RadioBrowserStation station) => ListTile(
        leading: _StationLogo(station: station, size: 42),
        title: Text(station.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${station.location}\n${station.technicalSummary}',
            maxLines: 2, overflow: TextOverflow.ellipsis),
        isThreeLine: true,
        onTap: () => unawaited(_play(station)),
        trailing: IconButton(
          tooltip: _isFavorite(station) ? 'Remover favorita' : 'Favoritar',
          onPressed: () => unawaited(_toggleFavorite(station)),
          icon: Icon(_isFavorite(station)
              ? Icons.star_rounded : Icons.star_border_rounded),
        ),
      );
}

class _StationLogo extends StatelessWidget {
  const _StationLogo({required this.station, required this.size});
  final RadioBrowserStation? station;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = station?.faviconUrl ?? '';
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.radio_rounded),
    );
    if (url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(url, width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback),
    );
  }
}

class _RadioMessage extends StatelessWidget {
  const _RadioMessage({required this.message, this.action});
  final String message;
  final Future<void> Function()? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.radio_rounded, size: 40),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              if (action != null) ...[
                const SizedBox(height: 10),
                FilledButton.tonal(
                  onPressed: () => unawaited(action!()),
                  child: const Text('Tentar novamente'),
                ),
              ],
            ],
          ),
        ),
      );
}
