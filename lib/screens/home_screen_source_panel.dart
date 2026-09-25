part of 'home_screen.dart';

extension _HomeSourcePanel on _HomeScreenState {
  Widget _buildSourcePanel(BuildContext context) {
    return _SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cameraswitch_outlined, size: 20),
              SizedBox(width: 8),
              Text(
                'Fonte de vídeo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<VideoSourceType>(
              segments: const [
                ButtonSegment(
                  value: VideoSourceType.localCamera,
                  icon: Icon(Icons.phone_android_rounded),
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text('Local')),
                ),
                ButtonSegment(
                  value: VideoSourceType.rtsp,
                  icon: Icon(Icons.router_outlined),
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text('RTSP')),
                ),
                ButtonSegment(
                  value: VideoSourceType.remotePhone,
                  icon: Icon(Icons.phone_android_rounded),
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text('Remoto')),
                ),
                ButtonSegment(
                  value: VideoSourceType.esp32,
                  icon: Icon(Icons.memory_rounded),
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text('ESP32')),
                ),
              ],
              selected: {_sourceType},
              onSelectionChanged: (values) {
                _updateSourcePanelState(() => _sourceType = values.first);
                _schedulePersist();
              },
            ),
          ),
          if (_sourceType == VideoSourceType.rtsp) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _rtspController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Endereço RTSP',
                hintText: 'rtsp://usuario:senha@192.168.1.20:554/stream',
                helperText: 'Salvo somente no armazenamento privado do aparelho.',
                prefixIcon: Icon(Icons.link_rounded),
              ),
            ),
          ],
          if (_sourceType == VideoSourceType.remotePhone) ...[
            const SizedBox(height: 12),
            const Text(
              'Conecte outro aparelho pelo endereço manual ou lendo o QR exibido no Modo Câmera.',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _scanRemotePhoneQr,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Escanear QR do outro celular'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _updateSourcePanelState(() {
                    _remoteUrlController.clear();
                    _remoteKeyController.clear();
                  }),
                  icon: const Icon(Icons.clear_rounded),
                  label: const Text('Limpar campos'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _remoteUrlController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Endereço do celular',
                hintText: 'http://192.168.1.10:8765',
                helperText: 'Use o endereço exibido no Modo Câmera do outro aparelho.',
                prefixIcon: Icon(Icons.wifi_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _remoteKeyController,
              autocorrect: false,
              enableSuggestions: false,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Chave de sessão',
                prefixIcon: Icon(Icons.key_rounded),
              ),
            ),
          ],
          if (_sourceType == VideoSourceType.esp32) ...[
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final modules = _cameraRegistry.items
                    .where((camera) =>
                        camera.enabled &&
                        camera.type == CameraEndpointType.esp32 &&
                        camera.esp32CameraEnabled)
                    .toList(growable: false);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (modules.isEmpty)
                      const Text(
                        'Nenhum ESP32 com câmera está ativo. Conecte o módulo e marque “Câmera ESP32 instalada”.',
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: modules.any(
                                (camera) => camera.id == _selectedEsp32Id)
                            ? _selectedEsp32Id
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Fonte ESP32',
                          prefixIcon: Icon(Icons.memory_rounded),
                        ),
                        items: modules
                            .map(
                              (camera) => DropdownMenuItem<String>(
                                value: camera.id,
                                child: Text(camera.name),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          _updateSourcePanelState(
                            () => _selectedEsp32Id = value,
                          );
                          _schedulePersist();
                        },
                      ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const Esp32SettingsScreen(),
                          ),
                        );
                        if (mounted) _updateSourcePanelState(() {});
                      },
                      icon: const Icon(Icons.tune_rounded),
                      label: Text(
                        _esp32ModuleRegistry.modules.isEmpty
                            ? 'Conectar ESP32'
                            : 'Gerenciar ESP32',
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
