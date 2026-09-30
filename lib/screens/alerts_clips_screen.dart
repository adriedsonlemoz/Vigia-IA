import 'dart:async';

import 'package:flutter/material.dart';

import '../models/alert_preferences.dart';
import '../models/video_source_config.dart';
import '../services/app_settings_service.dart';
import '../services/native_platform_service.dart';

class AlertsClipsScreen extends StatefulWidget {
  const AlertsClipsScreen({super.key});

  @override
  State<AlertsClipsScreen> createState() => _AlertsClipsScreenState();
}

class _AlertsClipsScreenState extends State<AlertsClipsScreen> {
  final _settings = AppSettingsService.instance;
  final _native = NativePlatformService.instance;
  PersistedMonitorProfile? _profile;
  late AlertOutputs _outputs;
  late AlertMessages _messages;
  late Duration _clipDuration;
  late ClipFormatPreference _clipFormat;
  final Map<String, TextEditingController> _controllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final profile = await _settings.initialize();
    if (!mounted) return;
    final messages = profile.settings.alertMessages;
    _profile = profile;
    _outputs = profile.settings.alertOutputs;
    _messages = messages;
    _clipDuration = profile.settings.clipDuration;
    _clipFormat = profile.settings.clipFormatPreference;
    _controllers.addAll(<String, TextEditingController>{
      'person': TextEditingController(text: messages.person),
      'vehicle': TextEditingController(text: messages.vehicle),
      'animal': TextEditingController(text: messages.animal),
      'other': TextEditingController(text: messages.other),
      'entered': TextEditingController(text: messages.entered),
      'exited': TextEditingController(text: messages.exited),
      'cameraObstructed': TextEditingController(text: messages.cameraObstructed),
      'cameraMoved': TextEditingController(text: messages.cameraMoved),
    });
    setState(() {});
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final current = _profile;
    if (current == null) return;
    _messages = _messages.copyWith(
      person: _controllers['person']!.text.trim(),
      vehicle: _controllers['vehicle']!.text.trim(),
      animal: _controllers['animal']!.text.trim(),
      other: _controllers['other']!.text.trim(),
      entered: _controllers['entered']!.text.trim(),
      exited: _controllers['exited']!.text.trim(),
      cameraObstructed: _controllers['cameraObstructed']!.text.trim(),
      cameraMoved: _controllers['cameraMoved']!.text.trim(),
    );
    final next = PersistedMonitorProfile(
      source: current.source,
      settings: current.settings.copyWith(
        voiceEnabled: _outputs.voice,
        alertOutputs: _outputs,
        alertMessages: _messages,
        clipDuration: _clipDuration,
        clipFormatPreference: _clipFormat,
      ),
    );
    await _settings.saveProfile(next);
    _profile = next;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alertas e clipes atualizados.')));
    }
  }

  Future<void> _requestNotifications() async {
    final granted = await _native.requestNotificationPermission();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(granted ? 'Notificações Android autorizadas.' : 'Notificações não foram autorizadas.')),
    );
  }

  Future<void> _addOverride() async {
    final profile = _profile;
    if (profile == null) return;
    const groups = <String, String>{
      'person': 'Pessoas',
      'vehicle': 'Automóveis',
      'animal': 'Animais',
    };
    var selectedGroup = 'person';
    var selectedArea = '*';
    final message = TextEditingController(text: '{objeto} detectado em {area}.');
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Frase por grupo e área'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedGroup,
                  decoration: const InputDecoration(labelText: 'Grupo'),
                  items: groups.entries
                      .map(
                        (entry) => DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => selectedGroup = value);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedArea,
                  decoration: const InputDecoration(labelText: 'Área'),
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem(value: '*', child: Text('Qualquer área')),
                    ...profile.settings.monitoringZones.map(
                      (zone) => DropdownMenuItem(value: zone.name, child: Text(zone.name)),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => selectedArea = value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: message,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Frase',
                    helperText: 'Você pode usar {objeto} e {area}',
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
                final text = message.text.trim();
                if (text.isEmpty) return;
                Navigator.pop(dialogContext, <String, String>{
                  'key': '$selectedGroup|$selectedArea',
                  'message': text,
                });
              },
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
    message.dispose();
    if (result == null || !mounted) return;
    setState(() {
      _messages = _messages.copyWith(
        byObjectAndArea: <String, String>{
          ..._messages.byObjectAndArea,
          result['key']!: result['message']!,
        },
      );
    });
  }

  String _overrideTitle(String key) {
    final parts = key.split('|');
    final group = parts.isEmpty ? key : parts.first;
    final groupName = switch (group) {
      'person' => 'Pessoas',
      'vehicle' => 'Automóveis',
      'animal' => 'Animais',
      _ => 'Grupo antigo',
    };
    final area = parts.length < 2 || parts[1] == '*' ? 'Qualquer área' : parts[1];
    return '$groupName · $area';
  }



  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final outputAndClipWidgets = <Widget>[
      const _Header(
        title: 'Como avisar',
        subtitle: 'Combine as formas de alerta que fizerem sentido.',
      ),
      _SwitchTile(
        icon: Icons.record_voice_over_outlined,
        title: 'Voz',
        value: _outputs.voice,
        onChanged: (value) =>
            setState(() => _outputs = _outputs.copyWith(voice: value)),
      ),
      _SwitchTile(
        icon: Icons.volume_up_outlined,
        title: 'Som da notificação',
        value: _outputs.sound,
        onChanged: (value) =>
            setState(() => _outputs = _outputs.copyWith(sound: value)),
      ),
      _SwitchTile(
        icon: Icons.vibration_rounded,
        title: 'Vibração',
        value: _outputs.vibration,
        onChanged: (value) =>
            setState(() => _outputs = _outputs.copyWith(vibration: value)),
      ),
      _SwitchTile(
        icon: Icons.notifications_active_outlined,
        title: 'Notificação Android',
        value: _outputs.androidNotification,
        onChanged: (value) => setState(
          () => _outputs = _outputs.copyWith(androidNotification: value),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _requestNotifications,
          icon: const Icon(Icons.security_outlined),
          label: const Text('Conferir permissão de notificações'),
        ),
      ),
      const SizedBox(height: 14),
      const _Header(
        title: 'Clipes dos eventos',
        subtitle: 'MP4 H.264 é prioritário no Android; GIF permanece como fallback.',
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Duração do clipe',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '${_clipDuration.inSeconds}s',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              Slider(
                value: _clipDuration.inSeconds.toDouble(),
                min: 3,
                max: 20,
                divisions: 17,
                onChanged: (value) => setState(
                  () => _clipDuration = Duration(seconds: value.round()),
                ),
              ),
              SegmentedButton<ClipFormatPreference>(
                segments: const [
                  ButtonSegment(
                    value: ClipFormatPreference.mp4WithGifFallback,
                    icon: Icon(Icons.movie_outlined),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('MP4 + fallback'),
                    ),
                  ),
                  ButtonSegment(
                    value: ClipFormatPreference.gifOnly,
                    icon: Icon(Icons.gif_box_outlined),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Somente GIF'),
                    ),
                  ),
                ],
                selected: {_clipFormat},
                onSelectionChanged: (value) =>
                    setState(() => _clipFormat = value.first),
              ),
            ],
          ),
        ),
      ),
    ];

    final messageWidgets = <Widget>[
      const _Header(
        title: 'Frases personalizadas',
        subtitle:
            'Alertas visuais e de voz usam somente Pessoas, Automóveis e Animais. Entrada/saída registra transições; não é um contador.',
      ),
      _messageField('person', 'Pessoa'),
      _messageField('vehicle', 'Automóvel'),
      _messageField('animal', 'Animal'),
      _messageField('entered', 'Entrada (não é contador)'),
      _messageField('exited', 'Saída (não é contador)'),
      _messageField('cameraObstructed', 'Câmera obstruída'),
      _messageField('cameraMoved', 'Câmera deslocada'),
      const SizedBox(height: 6),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Regras específicas por grupo + área',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: _addOverride,
            tooltip: 'Adicionar regra',
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      if (_messages.byObjectAndArea.isEmpty)
        const Text('Nenhuma frase específica. As frases gerais acima serão usadas.')
      else
        ..._messages.byObjectAndArea.entries.map(
          (entry) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.record_voice_over_outlined),
            title: Text(_overrideTitle(entry.key)),
            subtitle: Text(entry.value),
            trailing: IconButton(
              onPressed: () => setState(() {
                final map = <String, String>{..._messages.byObjectAndArea}
                  ..remove(entry.key);
                _messages = _messages.copyWith(byObjectAndArea: map);
              }),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ),
        ),
    ];

    Widget saveButton() => FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('SALVAR ALTERAÇÕES'),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas e clipes'),
        actions: [
          IconButton(
            onPressed: _save,
            tooltip: 'Salvar',
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 840;
            if (wide) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(18, 12, 9, 24),
                          children: outputAndClipWidgets,
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(9, 12, 18, 24),
                          children: [
                            ...messageWidgets,
                            const SizedBox(height: 14),
                            saveButton(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                ...outputAndClipWidgets,
                const SizedBox(height: 18),
                ...messageWidgets,
                const SizedBox(height: 18),
                saveButton(),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _messageField(String key, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: TextField(controller: _controllers[key], maxLines: 2, decoration: InputDecoration(labelText: label)),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(subtitle, style: Theme.of(context).textTheme.bodySmall)]),
      );
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({required this.icon, required this.title, required this.value, required this.onChanged});
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Card(
        child: SwitchListTile(value: value, onChanged: onChanged, secondary: Icon(icon), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
      );
}
