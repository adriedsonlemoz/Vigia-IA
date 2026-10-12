import 'dart:async';

import 'package:flutter/material.dart';

import '../services/map_radio_service.dart';
import '../services/map_ride_settings_service.dart';
import '../services/radio_browser_service.dart';
import '../services/radio_health_service.dart';
import '../services/data_usage_service.dart';
import '../services/radio_recent_history.dart';
import '../services/radio_sleep_timer.dart';

enum _RadioSection { discover, recent, favorites, manual }

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
  final _history = RadioRecentHistory();
  List<RadioRecentEntry> _recent = const <RadioRecentEntry>[];
  RadioBrowserStation? _pendingStation;
  bool _initialPlayingSyncPending = true;
  String _genre = 'Todos';
  String _language = 'Todos';
  int _maxBitrate = 0;
  final _queryController = TextEditingController();
  final _manualNameController = TextEditingController();
  final _manualUrlController = TextEditingController();
  List<RadioBrowserStation> _results = const <RadioBrowserStation>[];
  _RadioSection _section = _RadioSection.discover;
  bool _brazilOnly = true;
  bool _loading = false;
  String? _error;
  String _playbackState = 'parado';
  String _nowPlaying = '';
  bool _fromCache = false;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRecent());
    unawaited(_refreshPlayback());
    unawaited(RadioHealthService.instance.load().then((_) {
      if (mounted) setState(() {});
    }));
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

  Future<void> _loadRecent() async {
    final entries = await _history.load();
    if (mounted) setState(() => _recent = entries);
  }

  Future<void> _recordRecent(RadioBrowserStation station) async {
    final entries = await _history.record(station);
    if (mounted) setState(() => _recent = entries);
  }

  List<RadioBrowserStation> get _visibleResults => _results.where((station) {
    if (_genre != 'Todos' &&
        !station.tags.toLowerCase().contains(_genre.toLowerCase())) return false;
    if (_language != 'Todos' &&
        !station.language.toLowerCase().contains(_language.toLowerCase())) return false;
    if (_maxBitrate > 0 && station.bitrate > _maxBitrate) return false;
    return true;
  }).toList(growable: false);

  List<RadioBrowserStation> get _favorites => widget.settings.stations
      .map(RadioBrowserStation.fromSavedMap)
      .where((station) => station.streamUrl.isNotEmpty)
      .toList(growable: false);

  RadioBrowserStation? get _selected {
    final url = widget.settings.radioUrl;
    if (url.isEmpty) return null;
    for (final station in <RadioBrowserStation>[
      ..._favorites, ..._recent.map((e) => e.station), ..._results]) {
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
      final previous = _playbackState;
      if (previous != status.state || _nowPlaying != status.nowPlaying) {
        setState(() {
          _playbackState = status.state;
          _nowPlaying = status.nowPlaying;
        });
      }
      if (status.state == 'tocando' && _pendingStation != null &&
          (status.url == _pendingStation!.streamUrl ||
              status.station == _pendingStation!.name)) {
        final station = _pendingStation!;
        _pendingStation = null;
        _initialPlayingSyncPending = false;
        unawaited(_recordRecent(station));
      } else if (status.state == 'tocando' && _initialPlayingSyncPending &&
          _pendingStation == null && _selected != null) {
        // Recupera reprodução iniciada antes de minimizar o painel.
        _initialPlayingSyncPending = false;
        unawaited(_recordRecent(_selected!));
      }
      if (previous == status.state) return;
      widget.onPlaybackStateChanged(status.state);
      final url = widget.settings.radioUrl;
      if (status.state == 'tocando') {
        unawaited(RadioHealthService.instance.markWorking(url));
      } else if (status.state == 'indisponível' &&
          (previous == 'conectando' || previous == 'tocando')) {
        // Só avisa quando uma estação que estava ativa deixa de responder.
        unawaited(RadioHealthService.instance.markFailed(url));
        final name = _selected?.name ?? 'A estação';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$name não respondeu. Tente outra estação ou confira a conexão.',
            ),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await RadioHealthService.instance.load();
      final results = await _catalog.search(
        query: _queryController.text,
        brazilOnly: _brazilOnly,
        preferLowBitrate: DataUsageService.instance.dataSaverEnabled,
      );
      if (!mounted) return;
      setState(() {
        _results = RadioBrowserService.rankStations(
          results,
          isSuspect: RadioHealthService.instance.isSuspect,
        );
        _fromCache = _catalog.lastSearchFromCache;
      });
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
      _pendingStation = station;
      await widget.settings.update(
        stationName: station.name,
        stationUrl: station.streamUrl,
        radioBitrateKbps: station.bitrate,
      );
      unawaited(_catalog.registerClick(station));
      await MapRadioService.play(
        name: station.name,
        url: station.streamUrl,
        volume: widget.settings.radioVolume,
        bitrateKbps: station.bitrate,
      );
      if (!mounted) return;
      setState(() => _playbackState = 'conectando');
      widget.onPlaybackStateChanged('conectando');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _refreshPlayback();
    } catch (error) {
      _pendingStation = null;
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
    RadioSleepTimer.cancel();
    await MapRadioService.stop();
    await _refreshPlayback();
  }

  void _skip(int offset) {
    final stations = _section == _RadioSection.recent && _recent.isNotEmpty
        ? _recent.map((e) => e.station).toList()
        : _favorites.isNotEmpty ? _favorites : _visibleResults;
    if (stations.isEmpty) return;
    final current = stations.indexWhere(
      (station) => station.streamUrl == widget.settings.radioUrl,
    );
    final step = offset >= 0 ? 1 : -1;
    // Sem estação atual na lista: "Próxima" começa no início e "Anterior" no fim.
    var index = current < 0
        ? (step > 0 ? 0 : stations.length - 1)
        : (current + offset) % stations.length;
    // Pula estações marcadas como instáveis, se existirem outras.
    final health = RadioHealthService.instance;
    for (var tries = 0;
        tries < stations.length && health.isSuspect(stations[index].streamUrl);
        tries++) {
      index = (index + step) % stations.length;
    }
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
                tooltip: 'Minimizar e continuar tocando',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.minimize_rounded),
              ),
              IconButton(
                tooltip: 'Parar e fechar rádio',
                onPressed: () async {
                  await _stop();
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        _buildPlayer(scheme),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: LayoutBuilder(builder: (context, constraints) {
            // Em telas estreitas, ícones e rótulos ficam em duas linhas.
            const tabs = <(_RadioSection, IconData, String)>[
              (_RadioSection.discover, Icons.search_rounded, 'Buscar'),
              (_RadioSection.recent, Icons.history_rounded, 'Recentes'),
              (_RadioSection.favorites, Icons.star_rounded, 'Favoritas'),
              (_RadioSection.manual, Icons.link_rounded, 'URL'),
            ];
            return Row(children: [
              for (final tab in tabs)
                Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Material(
                    borderRadius: BorderRadius.circular(12),
                    color: _section == tab.$1
                        ? scheme.primaryContainer : scheme.surfaceContainerLow,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _section = tab.$1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(tab.$2, size: 19),
                          const SizedBox(height: 3),
                          Text(tab.$3, maxLines: 1, style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 11)),
                        ]),
                      ),
                    ),
                  ),
                )),
            ]);
          }),
        ),
        Expanded(child: switch (_section) {
          _RadioSection.discover => _buildDiscovery(),
          _RadioSection.recent => _buildRecents(),
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          scheme.primaryContainer.withValues(alpha: 0.55),
          scheme.surfaceContainerHighest.withValues(alpha: 0.65),
        ]),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _StationLogo(station: station, size: 44),
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
                    if (_nowPlaying.isNotEmpty && _playbackState == 'tocando')
                      Text('♪ $_nowPlaying',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: scheme.primary)),
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
                    : (_playbackState == 'tocando' ||
                            _playbackState == 'conectando')
                        ? 'Pausar'
                        : 'Tocar'),
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
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _showSleepOptions,
              icon: const Icon(Icons.bedtime_outlined, size: 17),
              label: Text(RadioSleepTimer.endAt == null
                  ? 'Desligar depois…' : 'Temporizador ativo'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSleepOptions() async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (dialogContext) => SafeArea(
        child: Wrap(children: [
          const ListTile(title: Text('Desligar rádio automaticamente')),
          for (final duration in const [15, 30, 60, 90])
            ListTile(
              leading: const Icon(Icons.bedtime_outlined),
              title: Text('Em $duration minutos'),
              onTap: () => Navigator.of(dialogContext).pop(duration),
            ),
          ListTile(
            leading: const Icon(Icons.timer_off_outlined),
            title: const Text('Cancelar temporizador'),
            onTap: () => Navigator.of(dialogContext).pop(0),
          ),
        ]),
      ),
    );
    if (minutes == null || !mounted) { return; }
    if (minutes == 0) {
      RadioSleepTimer.cancel();
    } else {
      RadioSleepTimer.schedule(Duration(minutes: minutes));
    }
    setState(() {});
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
          SizedBox(height: 40, child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _radioFilterMenu<String>(
                'Estilo: $_genre', _genre,
                const ['Todos', 'rock', 'pop', 'jazz', 'news', 'sertanejo', 'gospel'],
                (value) => setState(() => _genre = value),
              ),
              const SizedBox(width: 7),
              _radioFilterMenu<String>(
                'Idioma: ${_radioFilterLabel(_language)}', _language,
                const ['Todos', 'portuguese', 'english', 'spanish'],
                (value) => setState(() => _language = value),
              ),
              const SizedBox(width: 7),
              _radioFilterMenu<int>(
                _maxBitrate == 0 ? 'Qualidade: todas' : 'Até $_maxBitrate kb/s',
                _maxBitrate, const [0, 64, 96, 128],
                (value) => setState(() => _maxBitrate = value),
              ),
            ],
          )),
          if (_fromCache)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                'Sem acesso ao catálogo agora: mostrando a última busca salva.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: _error != null && _results.isEmpty
                ? _RadioMessage(message: _error!, action: _search)
                : _visibleResults.isEmpty && !_loading
                    ? const _RadioMessage(message: 'Sem rádios para estes filtros. Ajuste estilo ou qualidade.')
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                        itemCount: _visibleResults.length,
                        itemBuilder: (context, index) =>
                            _stationTile(_visibleResults[index]),
                      ),
          ),
        ],
      );

  String _radioFilterLabel(Object value) => switch (value) {
    'portuguese' => 'Português',
    'english' => 'Inglês',
    'spanish' => 'Espanhol',
    'news' => 'Notícias',
    'rock' => 'Rock',
    'pop' => 'Pop',
    'jazz' => 'Jazz',
    'sertanejo' => 'Sertanejo',
    'gospel' => 'Gospel',
    _ => value.toString(),
  };

  Widget _radioFilterMenu<T>(String label, T selected, List<T> values,
      ValueChanged<T> onSelect) => PopupMenuButton<T>(
    tooltip: 'Filtrar rádios',
    initialValue: selected,
    onSelected: onSelect,
    itemBuilder: (context) => [
      for (final value in values)
        PopupMenuItem(value: value, child: Text(
          value == 0 ? 'Todas as qualidades' : _radioFilterLabel(value),
        )),
    ],
    child: Chip(
      visualDensity: VisualDensity.compact,
      label: Text(label, style: const TextStyle(fontSize: 12)),
      avatar: const Icon(Icons.tune_rounded, size: 16),
    ),
  );

  Widget _buildRecents() {
    if (_recent.isEmpty) {
      return const _RadioMessage(message:
        'As estações que começarem a tocar aparecerão aqui, até 20 rádios.');
    }
    return Column(children: [
      Align(alignment: Alignment.centerRight, child: TextButton.icon(
        onPressed: () async {
          await _history.clear();
          if (mounted) setState(() => _recent = const []);
        },
        icon: const Icon(Icons.delete_sweep_outlined, size: 18),
        label: const Text('Limpar histórico'),
      )),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        itemCount: _recent.length,
        itemBuilder: (context, index) {
          final entry = _recent[index];
          return ListTile(
            leading: _StationLogo(station: entry.station, size: 40),
            title: Text(entry.station.name, maxLines: 1,
              overflow: TextOverflow.ellipsis),
            subtitle: Text('${entry.station.technicalSummary} · ${_recentDate(entry.playedAt)}',
              maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => unawaited(_play(entry.station)),
            trailing: IconButton(
              tooltip: 'Remover do histórico',
              icon: const Icon(Icons.close_rounded),
              onPressed: () async {
                final entries = await _history.remove(entry.station.streamUrl);
                if (mounted) setState(() => _recent = entries);
              },
            ),
          );
        },
      )),
    ]);
  }

  String _recentDate(DateTime when) {
    final local = when.toLocal();
    final now = DateTime.now();
    if (local.year == now.year && local.month == now.month &&
        local.day == now.day) return 'hoje';
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}';
  }

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
          if (DataUsageService.instance.dataSaverEnabled) ...[
            const SizedBox(height: 8),
            const Text('Economia de dados ativa: estações de até 96 kb/s têm prioridade quando disponíveis.'),
          ],
        ],
      );

  Widget _stationTile(RadioBrowserStation station) => ListTile(
        leading: _StationLogo(station: station, size: 42),
        title: Text(station.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
            '${station.location}\n${station.technicalSummary}'
            '${RadioHealthService.instance.isSuspect(station.streamUrl) ? ' · pode estar fora do ar' : ''}',
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
