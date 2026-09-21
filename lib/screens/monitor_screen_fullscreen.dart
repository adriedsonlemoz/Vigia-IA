part of 'monitor_screen.dart';

extension _MonitorFullscreen on _MonitorScreenState {
  Future<void> _toggleFullscreen() async {
    if (_fullscreenChanging) return;
    _fullscreenChanging = true;
    final entering = !_fullscreen;
    if (entering) {
      _orientationBeforeFullscreen = MediaQuery.orientationOf(context);
      _fillBeforeFullscreen = _fillPreview;
    }
    _updateFullscreenState(() {
      _fullscreen = entering;
      _fillPreview = entering ? true : _fillBeforeFullscreen;
      _fullscreenControlsVisible = true;
      _editingZoneId = null;
    });
    try {
      if (entering) {
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight,
        ]);
        if (mounted) await SystemUiService.immersive();
        _revealFullscreenControls();
      } else {
        _fullscreenControlsTimer?.cancel();
        await SystemUiService.edgeToEdge();
        await SystemChrome.setPreferredOrientations(
          _orientationBeforeFullscreen == Orientation.portrait
              ? const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]
              : const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
        );
        // Devolve a rotação automática depois de restaurar a orientação anterior.
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      }
    } finally {
      if (mounted) _updateFullscreenState(() => _fullscreenChanging = false);
    }
  }

  void _revealFullscreenControls() {
    if (!mounted || !_fullscreen) return;
    if (!_fullscreenControlsVisible) _updateFullscreenState(() => _fullscreenControlsVisible = true);
    _fullscreenControlsTimer?.cancel();
    _fullscreenControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _fullscreen) _updateFullscreenState(() => _fullscreenControlsVisible = false);
    });
  }

  Widget _monitorMenu() => PopupMenuButton<String>(
    tooltip: 'Mais opções',
    onSelected: (value) {
      if (_fullscreenChanging) return;
      switch (value) {
        case 'lan': unawaited(_showLanAccess());
        case 'status': unawaited(_showSessionStatus());
        case 'events': unawaited(_openStandardScreen(const EventsScreen()));
        case 'settings': unawaited(_openStandardScreen(const SettingsScreen()));
      }
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'lan', child: Text('Rede local')),
      PopupMenuItem(value: 'status', child: Text('Status da sessão')),
      PopupMenuItem(value: 'events', child: Text('Eventos')),
      PopupMenuItem(value: 'settings', child: Text('Configurações')),
    ],
  );

  Widget _voiceButton() => IconButton(
    tooltip: _controller.voiceEnabled ? 'Desativar voz' : 'Ativar voz',
    onPressed: () => _controller.setVoiceEnabled(!_controller.voiceEnabled),
    icon: Icon(_controller.voiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded),
  );

  Widget _buildFullscreen(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => _revealFullscreenControls(),
    child: Stack(fit: StackFit.expand, children: [
      _buildCameraStage(context),
      if (_fullscreenControlsVisible)
        Positioned(left: 0, right: 0, bottom: 0, child: SafeArea(
          top: false,
          minimum: const EdgeInsets.all(8),
          child: Material(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
            child: Row(children: [
              IconButton(
                tooltip: 'Sair da tela inteira',
                onPressed: _fullscreenChanging ? null : () => unawaited(_toggleFullscreen()),
                icon: const Icon(Icons.fullscreen_exit_rounded),
              ),
              Expanded(child: Text('Detectados $_currentDetectionCount',
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              IconButton(
                tooltip: _fillPreview ? 'Ajustar: mostrar imagem completa' : 'Preencher: ocupar a tela',
                onPressed: () => _updateFullscreenState(() => _fillPreview = !_fillPreview),
                icon: Icon(_fillPreview ? Icons.fit_screen_rounded : Icons.crop_free_rounded),
              ),
              _voiceButton(),
              _monitorMenu(),
            ]),
          ),
        )),
    ]),
  );
}
