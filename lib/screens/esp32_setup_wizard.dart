import 'dart:async';

import 'package:flutter/material.dart';

import '../models/esp32_module.dart';
import '../services/esp32_module_service.dart';

class Esp32SetupWizard extends StatefulWidget {
  const Esp32SetupWizard({
    super.key,
    this.existing,
  });

  final Esp32Module? existing;

  @override
  State<Esp32SetupWizard> createState() => _Esp32SetupWizardState();
}

class _Esp32SetupWizardState extends State<Esp32SetupWizard> {
  static const int _stepCount = 5;

  final Esp32ModuleService _registry = Esp32ModuleService.instance;
  late final PageController _pages;
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _key;
  late final TextEditingController _customPosition;
  late final TextEditingController _circumference;
  late final TextEditingController _magnets;
  late final TextEditingController _pressure;
  late final TextEditingController _temperature;

  int _step = 0;
  bool _enabled = true;
  bool _testing = false;
  bool _showManualConnection = false;
  Esp32ModulePosition _position = Esp32ModulePosition.unspecified;
  Set<Esp32Capability> _capabilities = <Esp32Capability>{};
  int _interval = 1000;
  int _protocolVersion = 1;
  Esp32ProbeResult? _probe;
  String? _inlineError;

  Esp32Module? get _existing => widget.existing;

  @override
  void initState() {
    super.initState();
    final existing = _existing;
    _pages = PageController();
    _name = TextEditingController(text: existing?.name ?? 'ESP32 Bike');
    _address = TextEditingController(
      text: existing?.address ?? 'http://192.168.4.1',
    );
    _key = TextEditingController(text: existing?.accessKey ?? '');
    _customPosition = TextEditingController(
      text: existing?.customPositionLabel ?? '',
    );
    _circumference = TextEditingController(
      text: (existing?.wheelCircumferenceMm ?? 2100).toStringAsFixed(0),
    );
    _magnets = TextEditingController(
      text: (existing?.hallMagnets ?? 1).toString(),
    );
    _pressure = TextEditingController(
      text: (existing?.minimumTirePressurePsi ?? 30).toStringAsFixed(1),
    );
    _temperature = TextEditingController(
      text: (existing?.maximumTemperatureC ?? 65).toStringAsFixed(1),
    );
    _enabled = existing?.enabled ?? true;
    _position = existing?.position ?? Esp32ModulePosition.unspecified;
    _capabilities = <Esp32Capability>{...?existing?.capabilities};
    _interval = existing?.telemetryIntervalMs ?? 1000;
    _protocolVersion = existing?.protocolVersion ?? 1;
    _showManualConnection = existing != null;
  }

  @override
  void dispose() {
    _pages.dispose();
    for (final controller in <TextEditingController>[
      _name,
      _address,
      _key,
      _customPosition,
      _circumference,
      _magnets,
      _pressure,
      _temperature,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _testConnection({bool tryKnownAddresses = true}) async {
    if (_testing) return;
    setState(() {
      _testing = true;
      _inlineError = null;
      _probe = null;
    });

    final candidates = <String>[];
    void addCandidate(String raw) {
      final normalized = raw.trim();
      if (normalized.isNotEmpty && !candidates.contains(normalized)) {
        candidates.add(normalized);
      }
    }

    addCandidate(_address.text);
    if (tryKnownAddresses) {
      addCandidate('http://192.168.4.1');
      addCandidate('http://esp32.local');
    }

    Esp32ProbeResult? lastResult;
    for (final candidate in candidates) {
      final uri = Uri.tryParse(candidate);
      if (uri == null ||
          uri.host.isEmpty ||
          !(uri.scheme == 'http' || uri.scheme == 'https')) {
        continue;
      }
      final result = await _registry.probe(
        _draftModule(addressOverride: candidate, forceEnabled: true),
      );
      if (!mounted) return;
      lastResult = result;
      if (result.online) {
        setState(() {
          _address.text = candidate;
          _probe = result;
          _protocolVersion = result.protocolVersion ?? _protocolVersion;
          if (result.reportedCapabilities.isNotEmpty) {
            _capabilities.addAll(result.reportedCapabilities);
          }
          _testing = false;
        });
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _probe = lastResult;
      _testing = false;
      _showManualConnection = true;
      _inlineError =
          'Não encontrei um ESP32 automaticamente. Confira o Wi‑Fi do módulo ou informe o endereço abaixo.';
    });
  }

  Esp32Module _draftModule({
    String? addressOverride,
    bool? forceEnabled,
  }) {
    final wheel =
        double.tryParse(_circumference.text.replaceAll(',', '.')) ?? 2100;
    final magnetCount = int.tryParse(_magnets.text) ?? 1;
    final minimumPressure =
        double.tryParse(_pressure.text.replaceAll(',', '.')) ?? 30;
    final maximumTemperature =
        double.tryParse(_temperature.text.replaceAll(',', '.')) ?? 65;
    final customLabel = _customPosition.text.trim();
    return Esp32Module(
      id: _existing?.id ?? 'esp32_${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim().isEmpty ? 'ESP32' : _name.text.trim(),
      address: addressOverride ?? _address.text.trim(),
      accessKey: _key.text.trim().isEmpty ? null : _key.text.trim(),
      enabled: forceEnabled ?? _enabled,
      position: _position,
      customPositionLabel:
          _position == Esp32ModulePosition.custom ? customLabel : null,
      capabilities: Set<Esp32Capability>.unmodifiable(_capabilities),
      wheelCircumferenceMm: wheel,
      hallMagnets: magnetCount,
      minimumTirePressurePsi: minimumPressure,
      maximumTemperatureC: maximumTemperature,
      telemetryIntervalMs: _interval,
      protocolVersion: _protocolVersion,
    );
  }

  bool _validateCurrentStep() {
    String? error;
    switch (_step) {
      case 0:
        final uri = Uri.tryParse(_address.text.trim());
        if (uri == null ||
            uri.host.isEmpty ||
            !(uri.scheme == 'http' || uri.scheme == 'https')) {
          error = 'Informe um endereço válido, como http://192.168.4.1.';
        }
        break;
      case 1:
        if (_name.text.trim().isEmpty) {
          error = 'Dê um nome para identificar este ESP32.';
        } else if (_position == Esp32ModulePosition.custom &&
            _customPosition.text.trim().isEmpty) {
          error = 'Informe o nome da posição personalizada.';
        }
        break;
      case 2:
        if (_capabilities.isEmpty) {
          error = 'Selecione pelo menos uma função ou sensor deste módulo.';
        }
        break;
      case 3:
        if (_capabilities.contains(Esp32Capability.hallSpeed)) {
          final wheel =
              double.tryParse(_circumference.text.replaceAll(',', '.'));
          final magnetCount = int.tryParse(_magnets.text);
          if (wheel == null || wheel < 500 || wheel > 4000) {
            error = 'A circunferência da roda deve ficar entre 500 e 4000 mm.';
          } else if (magnetCount == null ||
              magnetCount < 1 ||
              magnetCount > 32) {
            error = 'A quantidade de ímãs deve ficar entre 1 e 32.';
          }
        }
        if (error == null &&
            _capabilities.contains(Esp32Capability.tirePressure)) {
          final minimumPressure =
              double.tryParse(_pressure.text.replaceAll(',', '.'));
          if (minimumPressure == null || minimumPressure <= 0) {
            error = 'Informe um limite de pressão maior que zero.';
          }
        }
        if (error == null &&
            _capabilities.contains(Esp32Capability.temperature)) {
          final maximumTemperature =
              double.tryParse(_temperature.text.replaceAll(',', '.'));
          if (maximumTemperature == null || maximumTemperature <= 0) {
            error = 'Informe um limite de temperatura maior que zero.';
          }
        }
        break;
      case 4:
        break;
    }
    setState(() => _inlineError = error);
    return error == null;
  }

  Future<void> _next() async {
    if (!_validateCurrentStep()) return;
    if (_step >= _stepCount - 1) {
      Navigator.of(context).pop(_draftModule());
      return;
    }
    setState(() {
      _inlineError = null;
      _step += 1;
    });
    await _pages.animateToPage(
      _step,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _back() async {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _inlineError = null;
      _step -= 1;
    });
    await _pages.animateToPage(
      _step,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Fechar',
        ),
        title: Text(_existing == null ? 'Conectar ESP32' : 'Configurar ESP32'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'Etapa ${_step + 1} de $_stepCount',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        _stepTitle(_step),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: (_step + 1) / _stepCount),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _connectionStep(context),
                  _identityStep(context),
                  _capabilitiesStep(context),
                  _configurationStep(context),
                  _reviewStep(context),
                ],
              ),
            ),
            if (_inlineError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 18, color: colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _inlineError!,
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _testing ? null : () => unawaited(_back()),
                    icon: Icon(
                      _step == 0 ? Icons.close_rounded : Icons.arrow_back_rounded,
                    ),
                    label: Text(_step == 0 ? 'Cancelar' : 'Voltar'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _testing ? null : () => unawaited(_next()),
                    icon: Icon(
                      _step == _stepCount - 1
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                    ),
                    label: Text(
                      _step == _stepCount - 1 ? 'Salvar módulo' : 'Continuar',
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

  Widget _connectionStep(BuildContext context) => _stepScroll(
        context,
        icon: Icons.wifi_find_rounded,
        title: 'Encontre o seu ESP32',
        description:
            'Ligue o módulo e conecte o celular à rede Wi‑Fi dele. O Vigia IA tenta os endereços mais comuns e confirma se o ESP32 está respondendo.',
        children: [
          FilledButton.icon(
            onPressed: _testing
                ? null
                : () => unawaited(_testConnection(tryKnownAddresses: true)),
            icon: _testing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.radar_rounded),
            label: Text(_testing ? 'Procurando...' : 'Procurar e testar ESP32'),
          ),
          const SizedBox(height: 12),
          if (_probe != null) _probeCard(context, _probe!),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.tune_rounded),
                  title: const Text('Endereço manual e chave'),
                  subtitle: const Text(
                    'Use somente se a busca automática não encontrar o módulo.',
                  ),
                  trailing: Icon(
                    _showManualConnection
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                  onTap: () => setState(
                    () => _showManualConnection = !_showManualConnection,
                  ),
                ),
                if (_showManualConnection)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _address,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                            labelText: 'Endereço local',
                            hintText: 'http://192.168.4.1',
                            prefixIcon: Icon(Icons.link_rounded),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _key,
                          autocorrect: false,
                          enableSuggestions: false,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Chave do módulo (opcional)',
                            helperText:
                                'Só é necessária quando o firmware exige autenticação.',
                            prefixIcon: Icon(Icons.key_rounded),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: _testing
                                ? null
                                : () => unawaited(
                                      _testConnection(
                                        tryKnownAddresses: false,
                                      ),
                                    ),
                            icon: const Icon(Icons.wifi_rounded),
                            label: const Text('Testar este endereço'),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _InfoNote(
            icon: Icons.info_outline_rounded,
            text:
                'Você pode continuar mesmo com o ESP32 desligado e testar novamente na última etapa.',
          ),
        ],
      );

  Widget _identityStep(BuildContext context) => _stepScroll(
        context,
        icon: Icons.badge_outlined,
        title: 'Identifique o módulo',
        description:
            'Use um nome e uma posição fáceis de reconhecer quando houver mais de um ESP32 na bike.',
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nome do módulo',
              hintText: 'Ex.: ESP32 traseiro',
              prefixIcon: Icon(Icons.memory_rounded),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Onde ele ficará?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: Esp32ModulePosition.values
                .map(
                  (position) => ChoiceChip(
                    label: Text(position.label),
                    selected: _position == position,
                    onSelected: (_) => setState(() => _position = position),
                  ),
                )
                .toList(growable: false),
          ),
          if (_position == Esp32ModulePosition.custom) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _customPosition,
              decoration: const InputDecoration(
                labelText: 'Nome da posição',
                hintText: 'Ex.: garfo, bolsa lateral, rack...',
                prefixIcon: Icon(Icons.edit_location_alt_outlined),
              ),
            ),
          ],
        ],
      );

  Widget _capabilitiesStep(BuildContext context) {
    final reported = _probe?.reportedCapabilities ?? const <Esp32Capability>{};
    const readyNow = <Esp32Capability>[
      Esp32Capability.camera,
      Esp32Capability.temperature,
      Esp32Capability.hallSpeed,
      Esp32Capability.tirePressure,
      Esp32Capability.battery,
    ];
    const future = <Esp32Capability>[
      Esp32Capability.mmWave,
      Esp32Capability.thermal,
      Esp32Capability.tof,
      Esp32Capability.ultrasonic,
      Esp32Capability.ambient,
      Esp32Capability.gps,
      Esp32Capability.light,
      Esp32Capability.actuator,
    ];
    return _stepScroll(
      context,
      icon: Icons.hub_outlined,
      title: 'O que existe neste ESP32?',
      description:
          'Marque apenas o hardware realmente instalado. Quando o firmware informar as capacidades, o Vigia IA já deixa as detectadas selecionadas.',
      children: [
        if (reported.isNotEmpty) ...[
          _InfoNote(
            icon: Icons.auto_awesome_rounded,
            text:
                'Detectado pelo módulo: ${reported.map((item) => item.label).join(', ')}.',
          ),
          const SizedBox(height: 16),
        ],
        _capabilityGroup(
          context,
          title: 'Disponíveis no app',
          subtitle: 'Já possuem integração ou telemetria preparada.',
          capabilities: readyNow,
          reported: reported,
        ),
        const SizedBox(height: 18),
        _capabilityGroup(
          context,
          title: 'Preparado para módulos futuros',
          subtitle:
              'Podem ser cadastrados agora; a interface específica será liberada conforme o hardware for adicionado.',
          capabilities: future,
          reported: reported,
        ),
      ],
    );
  }

  Widget _configurationStep(BuildContext context) {
    final hasTemperature =
        _capabilities.contains(Esp32Capability.temperature);
    final hasHall = _capabilities.contains(Esp32Capability.hallSpeed);
    final hasTires = _capabilities.contains(Esp32Capability.tirePressure);
    final hasCamera = _capabilities.contains(Esp32Capability.camera);
    return _stepScroll(
      context,
      icon: Icons.tune_rounded,
      title: 'Ajuste somente o necessário',
      description:
          'O Vigia IA mostra apenas os ajustes relacionados aos sensores escolhidos. Os valores podem ser alterados depois.',
      children: [
        if (hasCamera)
          const _InfoNote(
            icon: Icons.camera_alt_outlined,
            text:
                'A câmera será adicionada automaticamente às fontes de vídeo usando o mesmo endereço e chave deste módulo.',
          ),
        if (hasCamera) const SizedBox(height: 14),
        if (hasTemperature) ...[
          _sectionTitle(context, 'Temperatura', Icons.device_thermostat_rounded),
          TextField(
            controller: _temperature,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Alerta máximo (°C)',
              helperText: 'O app avisa quando a leitura ultrapassar este valor.',
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (hasHall) ...[
          _sectionTitle(context, 'Velocidade por Hall', Icons.speed_rounded),
          const Text(
            'A roda informa a distância por volta; “ímãs” é quantos pulsos o sensor recebe em cada volta.',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _circumference,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Circunferência (mm)',
                    hintText: '2100',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _magnets,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ímãs',
                    hintText: '1',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
        ],
        if (hasTires) ...[
          _sectionTitle(context, 'Pressão dos pneus', Icons.circle_outlined),
          TextField(
            controller: _pressure,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Alerta mínimo (PSI)',
              helperText: 'Abaixo deste valor o Vigia IA sinaliza pressão baixa.',
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (!hasTemperature && !hasHall && !hasTires && !hasCamera)
          const _InfoNote(
            icon: Icons.check_circle_outline_rounded,
            text:
                'Este conjunto de capacidades não precisa de ajuste específico nesta versão.',
          ),
        const SizedBox(height: 4),
        Card(
          margin: EdgeInsets.zero,
          child: ExpansionTile(
            leading: const Icon(Icons.settings_suggest_outlined),
            title: const Text('Comunicação e opções avançadas'),
            subtitle: const Text('O padrão de 1 segundo é recomendado.'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
                title: const Text('Módulo ativo'),
                subtitle: const Text(
                  'Desative para manter o cadastro sem consultar telemetria.',
                ),
              ),
              DropdownButtonFormField<int>(
                initialValue: _interval,
                decoration: const InputDecoration(
                  labelText: 'Intervalo da telemetria',
                  helperText:
                      'Intervalos maiores economizam energia, mas atualizam mais devagar.',
                ),
                items: const [
                  DropdownMenuItem(value: 500, child: Text('0,5 segundo')),
                  DropdownMenuItem(value: 1000, child: Text('1 segundo · recomendado')),
                  DropdownMenuItem(value: 2000, child: Text('2 segundos')),
                  DropdownMenuItem(value: 5000, child: Text('5 segundos · economia')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _interval = value);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewStep(BuildContext context) {
    final module = _draftModule();
    return _stepScroll(
      context,
      icon: Icons.fact_check_outlined,
      title: 'Confira e teste',
      description:
          'Revise o módulo antes de salvar. O teste confirma a comunicação, mas o cadastro também pode ser salvo para configurar o hardware depois.',
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      child: Icon(
                        module.cameraEnabled
                            ? Icons.camera_alt_outlined
                            : Icons.memory_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            module.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(module.positionLabel),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                _reviewRow('Endereço', module.address ?? 'Não informado'),
                _reviewRow(
                  'Telemetria',
                  '${module.telemetryIntervalMs / 1000 == 0.5 ? '0,5' : (module.telemetryIntervalMs / 1000).toStringAsFixed(0)} s',
                ),
                _reviewRow('Estado', module.enabled ? 'Ativo' : 'Desativado'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: module.capabilities
                      .map((item) => Chip(label: Text(item.label)))
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _testing
              ? null
              : () => unawaited(_testConnection(tryKnownAddresses: false)),
          icon: _testing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.wifi_tethering_rounded),
          label: Text(_testing ? 'Testando...' : 'Testar conexão agora'),
        ),
        if (_probe != null) ...[
          const SizedBox(height: 12),
          _probeCard(context, _probe!),
        ],
        const SizedBox(height: 12),
        const _InfoNote(
          icon: Icons.shield_outlined,
          text:
              'O endereço e a chave ficam protegidos no armazenamento local do Vigia IA.',
        ),
      ],
    );
  }

  Widget _capabilityGroup(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<Esp32Capability> capabilities,
    required Set<Esp32Capability> reported,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          ...capabilities.map(
            (capability) {
              final selected = _capabilities.contains(capability);
              final detected = reported.contains(capability);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: CheckboxListTile(
                  value: selected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _capabilities.add(capability);
                      } else {
                        _capabilities.remove(capability);
                      }
                    });
                  },
                  secondary: Icon(_capabilityIcon(capability)),
                  title: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(capability.label),
                      if (detected)
                        const Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('Detectado'),
                        ),
                    ],
                  ),
                  subtitle: Text(_capabilityDescription(capability)),
                  controlAffinity: ListTileControlAffinity.trailing,
                ),
              );
            },
          ),
        ],
      );

  Widget _probeCard(BuildContext context, Esp32ProbeResult result) {
    final colorScheme = Theme.of(context).colorScheme;
    final success = result.online;
    return Card(
      margin: EdgeInsets.zero,
      color: success
          ? colorScheme.primaryContainer.withValues(alpha: 0.55)
          : colorScheme.errorContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: success ? colorScheme.primary : colorScheme.error,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    success ? 'ESP32 encontrado' : 'ESP32 não respondeu',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(result.message ?? (success ? 'Conexão pronta.' : 'Offline')),
                  if (result.latency != null)
                    Text(
                      'Resposta em ${result.latency!.inMilliseconds} ms',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (result.firmwareVersion != null ||
                      result.protocolVersion != null)
                    Text(
                      '${result.firmwareVersion == null ? '' : 'Firmware ${result.firmwareVersion}'}${result.firmwareVersion != null && result.protocolVersion != null ? ' · ' : ''}${result.protocolVersion == null ? '' : 'Protocolo v${result.protocolVersion}'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepScroll(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required List<Widget> children,
  }) =>
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  icon,
                  size: 44,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                ...children,
              ],
            ),
          ),
        ),
      );

  Widget _sectionTitle(BuildContext context, String title, IconData icon) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
      );

  Widget _reviewRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );

  String _stepTitle(int step) => switch (step) {
        0 => 'Conexão',
        1 => 'Identificação',
        2 => 'Capacidades',
        3 => 'Configuração',
        _ => 'Revisão',
      };

  IconData _capabilityIcon(Esp32Capability capability) => switch (capability) {
        Esp32Capability.camera => Icons.camera_alt_outlined,
        Esp32Capability.temperature => Icons.device_thermostat_rounded,
        Esp32Capability.hallSpeed => Icons.speed_rounded,
        Esp32Capability.tirePressure => Icons.circle_outlined,
        Esp32Capability.battery => Icons.battery_std_rounded,
        Esp32Capability.mmWave => Icons.radar_rounded,
        Esp32Capability.thermal => Icons.thermostat_rounded,
        Esp32Capability.tof => Icons.straighten_rounded,
        Esp32Capability.ultrasonic => Icons.sensors_rounded,
        Esp32Capability.ambient => Icons.air_rounded,
        Esp32Capability.gps => Icons.gps_fixed_rounded,
        Esp32Capability.light => Icons.light_mode_outlined,
        Esp32Capability.actuator => Icons.settings_remote_rounded,
      };

  String _capabilityDescription(Esp32Capability capability) => switch (capability) {
        Esp32Capability.camera => 'Vídeo do ESP32-CAM ou câmera compatível.',
        Esp32Capability.temperature => 'Temperatura do módulo, caixa ou ambiente.',
        Esp32Capability.hallSpeed => 'Velocidade e distância pela rotação da roda.',
        Esp32Capability.tirePressure => 'Pressão dos pneus dianteiro e traseiro.',
        Esp32Capability.battery => 'Nível, tensão e alimentação do módulo.',
        Esp32Capability.mmWave => 'Presença, movimento e distância por radar mmWave.',
        Esp32Capability.thermal => 'Temperatura por matriz ou sensor térmico.',
        Esp32Capability.tof => 'Distância curta e precisa por Time-of-Flight.',
        Esp32Capability.ultrasonic => 'Distância por ultrassom.',
        Esp32Capability.ambient => 'Umidade, pressão, qualidade do ar e clima local.',
        Esp32Capability.gps => 'Posição GNSS própria do módulo.',
        Esp32Capability.light => 'Luminosidade e condições de luz.',
        Esp32Capability.actuator => 'Sirene, relé, iluminação ou outro acionamento.',
      };
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
