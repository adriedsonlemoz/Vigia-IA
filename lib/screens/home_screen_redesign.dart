part of 'home_screen.dart';

extension _HomeRedesign on _HomeScreenState {
  void _navigateMain(int index) {
    if (index == 0) return;
    if (index == 2) {
      unawaited(_start());
      return;
    }
    if (index == 4) {
      unawaited(_openSettings());
      return;
    }
    final Widget target = switch (index) {
      1 => const EventsScreen(),
      3 => const MultiCameraScreen(),
      _ => const HomeScreen(),
    };
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => target),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
    if (mounted) await _loadSettings();
  }

  void _openScreen(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  void _changeMode() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const LaunchModeScreen(manualReview: false),
      ),
      (_) => false,
    );
  }

  List<Widget> _monitorConfiguration(int activeZones) {
    return [
      _buildSourcePanel(context),
      const SizedBox(height: 14),
      _PrivacyCard(sourceType: _sourceType),
      const SizedBox(height: 20),
      _SectionTitle(
        eyebrow: 'MONITORAMENTO',
        title: 'O que a IA deve observar',
        subtitle:
            'Os ajustes mais usados ficam aqui; parâmetros técnicos ficam em Ajustes → Avançado.',
      ),
      const SizedBox(height: 10),
      _ActionCard(
        icon: Icons.filter_alt_outlined,
        title: 'Objetos monitorados',
        subtitle: objectFilterSummary(_alertLabels),
        badge: '${objectFilterGroupCount(_alertLabels)}/3',
        onTap: _configureObjectFilter,
      ),
      _ActionCard(
        icon: Icons.rule_outlined,
        title: 'Regras inteligentes',
        subtitle: smartAlertRulesSummary(_smartAlertRules),
        onTap: _configureSmartAlertRules,
      ),
      _ActionCard(
        icon: Icons.grid_view_rounded,
        title: 'Áreas de vigilância',
        subtitle: activeZones == 0
            ? 'Tela inteira. Áreas limitam onde a IA observa; elas não fazem contagem.'
            : '$activeZones ativa(s) de ${_monitoringZones.length}. Áreas limitam a região observada e não contam passagens.',
        badge: activeZones == 0 ? 'Tela toda' : '$activeZones',
      ),
      _ActionCard(
        icon: Icons.schedule_rounded,
        title: 'Agenda automática',
        subtitle: monitorScheduleSummary(_schedule),
        badge: _schedule.enabled ? 'Ativa' : 'Manual',
        onTap: _configureSchedule,
      ),
      const SizedBox(height: 14),
      const _SectionTitle(
        eyebrow: 'AUTOMAÇÃO',
        title: 'Recursos do monitor',
        subtitle: 'Ligue só o que fizer sentido para o seu cenário.',
      ),
      const SizedBox(height: 10),
      _FeatureGrid(
        motionOnly: _motionOnly,
        clipRecordingEnabled: _clipRecordingEnabled,
        trackingEnabled: _trackingEnabled,
        announceEntryExit: _trackingEnabled && _announceEntryExit,
        backgroundMonitoringEnabled: _backgroundMonitoringEnabled,
        voiceEnabled: _voiceEnabled,
        onMotionChanged: (value) {
          _updateHomeState(() => _motionOnly = value);
          _schedulePersist();
        },
        onClipChanged: (value) {
          _updateHomeState(() => _clipRecordingEnabled = value);
          _schedulePersist();
        },
        onTrackingChanged: (value) {
          _updateHomeState(() => _trackingEnabled = value);
          _schedulePersist();
        },
        onEntryExitChanged: _trackingEnabled
            ? (value) {
                _updateHomeState(() => _announceEntryExit = value);
                _schedulePersist();
              }
            : null,
        onBackgroundChanged: (value) {
          _updateHomeState(() => _backgroundMonitoringEnabled = value);
          _schedulePersist();
        },
        onVoiceChanged: (value) {
          _updateHomeState(() => _voiceEnabled = value);
          _schedulePersist();
        },
      ),
    ];
  }

  Widget _buildRedesignedHome(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final activeZones = _monitoringZones.where((zone) => zone.enabled).length;
    final sourceText = switch (_sourceType) {
      VideoSourceType.localCamera => 'Câmera deste celular',
      VideoSourceType.rtsp => 'Câmera RTSP',
      VideoSourceType.remotePhone => 'Celular remoto',
      VideoSourceType.esp32 => 'Câmera ESP32',
    };

    return AdaptiveMainScaffold(
      currentIndex: 0,
      onDestinationSelected: _navigateMain,
      appBar: _buildHomeAppBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
              children: [
                const VigiaSectionHeading(
                  title: 'O que você quer fazer?',
                  subtitle:
                      'Os modos principais ficam em destaque. Recursos técnicos continuam disponíveis sem ocupar a tela inicial.',
                ),
                const SizedBox(height: 12),
                _buildModeCards(),
                const SizedBox(height: 24),
                const VigiaSectionHeading(
                  title: 'Acessos rápidos',
                  subtitle: 'Entre direto nas áreas mais usadas do aplicativo.',
                ),
                const SizedBox(height: 10),
                _buildQuickActions(),
                const SizedBox(height: 24),
                VigiaSectionHeading(
                  title: 'Monitoramento atual',
                  subtitle:
                      'A Home mostra só o essencial. Fonte, regras e automações ficam recolhidas abaixo.',
                  trailing: VigiaStatusPill(
                    label: _schedule.enabled ? 'Agendado' : 'Pronto',
                    icon: _schedule.enabled
                        ? Icons.schedule_rounded
                        : Icons.check_circle_outline_rounded,
                    color: VigiaColors.green,
                  ),
                ),
                const SizedBox(height: 10),
                _buildCurrentMonitorCard(sourceText, activeZones),
                const SizedBox(height: 10),
                _buildMonitorPreparation(activeZones),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildHomeAppBar() {
    return AppBar(
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [VigiaColors.cyan, VigiaColors.blue],
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.visibility_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vigia IA',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  'Seu copiloto inteligente',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Alterar modo inicial',
          onPressed: _changeMode,
          icon: const Icon(Icons.swap_horiz_rounded),
        ),
        IconButton(
          tooltip: 'Ajustes',
          onPressed: () => unawaited(_openSettings()),
          icon: const Icon(Icons.settings_outlined),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildModeCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = <Widget>[
          VigiaModeCard(
            compact: true,
            icon: Icons.videocam_rounded,
            title: 'Monitor ao vivo',
            subtitle: 'Câmera, transmissão e IA em tempo real.',
            accent: VigiaColors.cyan,
            tags: const ['IA', 'Alertas'],
            onTap: () => unawaited(_start()),
          ),
          VigiaModeCard(
            compact: true,
            icon: Icons.cast_connected_rounded,
            title: 'Modo transmissão',
            subtitle: 'Envie a imagem deste aparelho pela rede local.',
            accent: VigiaColors.blue,
            tags: const ['LAN', 'Enviar'],
            onTap: () => _openScreen(const CameraModeScreen()),
          ),
          VigiaModeCard(
            compact: true,
            icon: Icons.directions_bike_rounded,
            title: 'Modo Bike',
            subtitle: 'Câmera, telemetria e sensores para a bike.',
            accent: VigiaColors.green,
            tags: const ['Sensores', 'Bike'],
            onTap: () => _openScreen(const BikeModeScreen()),
          ),
          VigiaModeCard(
            compact: true,
            icon: Icons.memory_rounded,
            title: 'ESP32',
            subtitle: 'Conecte o módulo e configure sensores e câmera.',
            accent: VigiaColors.blue,
            tags: const ['Módulo', 'Sensores'],
            onTap: () => _openScreen(const Esp32SettingsScreen()),
          ),
        ];
        final columns = constraints.maxWidth >= 780 ? 4 : 2;
        final spacing = constraints.maxWidth < 420 ? 8.0 : 10.0;
        final ratio = columns == 4
            ? 1.12
            : constraints.maxWidth < 420
                ? 0.95
                : 1.30;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: ratio,
          ),
          itemBuilder: (context, index) => cards[index],
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final actions = <({IconData icon, String label, VoidCallback onTap})>[
          (
            icon: Icons.video_library_outlined,
            label: 'Câmeras',
            onTap: () => _openScreen(const MultiCameraScreen()),
          ),
          (
            icon: Icons.map_outlined,
            label: 'Mapa',
            onTap: () => _openScreen(const MapMonitoringScreen()),
          ),
          (
            icon: Icons.history_rounded,
            label: 'Histórico',
            onTap: () => _openScreen(const EventsScreen()),
          ),
          (
            icon: Icons.monitor_heart_outlined,
            label: 'Diagnóstico',
            onTap: () => _openScreen(const ErrorCenterScreen()),
          ),
          (
            icon: Icons.settings_outlined,
            label: 'Ajustes',
            onTap: () => unawaited(_openSettings()),
          ),
        ];
        final columns = constraints.maxWidth < 520 ? 3 : 5;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: columns == 3 ? 1.08 : 0.92,
          ),
          itemBuilder: (context, index) {
            final action = actions[index];
            return VigiaQuickAction(
              icon: action.icon,
              label: action.label,
              onTap: action.onTap,
            );
          },
        );
      },
    );
  }

  Widget _buildCurrentMonitorCard(String sourceText, int activeZones) {
    return VigiaSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sourceText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activeZones == 0
                          ? 'IA observando a imagem inteira'
                          : '$activeZones área(s) de vigilância ativa(s)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Iniciar monitoramento'),
          ),
        ],
      ),
    );
  }

  Widget _buildMonitorPreparation(int activeZones) {
    return VigiaSurfaceCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.tune_rounded),
        title: const Text(
          'Preparar monitoramento',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: const Text('Fonte, objetos, regras, agenda e automações'),
        children: _monitorConfiguration(activeZones),
      ),
    );
  }
}
