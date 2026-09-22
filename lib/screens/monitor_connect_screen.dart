import 'dart:async';

import 'package:flutter/material.dart';

import '../models/video_source_config.dart';
import '../services/app_settings_service.dart';
import '../services/native_platform_service.dart';
import '../services/remote_camera_pairing_service.dart';
import 'monitor_screen.dart';
import 'multi_camera_screen.dart';
import 'phone_pairing_scanner_screen.dart';
import 'launch_mode_screen.dart';

class MonitorConnectScreen extends StatefulWidget {
  const MonitorConnectScreen({super.key});

  @override
  State<MonitorConnectScreen> createState() => _MonitorConnectScreenState();
}

class _MonitorConnectScreenState extends State<MonitorConnectScreen> {
  final _settings = AppSettingsService.instance;
  final _native = NativePlatformService.instance;
  final _addressController = TextEditingController();
  final _keyController = TextEditingController();

  bool _loading = true;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _addressController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await _settings.initialize();
    if (!mounted) return;
    setState(() {
      _addressController.text = profile.source.remoteBaseUrl ?? '';
      _keyController.text = profile.source.remoteAccessKey ?? '';
      _loading = false;
    });
  }

  Future<void> _scanQr() async {
    final granted = await _native.requestCameraPermission();
    if (!mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Permita a câmera para escanear o QR do transmissor.'),
          action: SnackBarAction(
            label: 'AJUSTES',
            onPressed: () => unawaited(_native.openAppSettings()),
          ),
        ),
      );
      return;
    }

    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const PhonePairingScannerScreen(),
      ),
    );
    if (!mounted || raw == null || raw.trim().isEmpty) return;

    try {
      final pairing = RemoteCameraPairingService.decode(raw);
      setState(() {
        _addressController.text = pairing.address;
        _keyController.text = pairing.accessKey;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transmissor preenchido: ${pairing.name}.')),
      );
    } on FormatException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message.toString())),
      );
    }
  }

  Future<void> _openMonitor() async {
    if (_opening) return;
    final address = _addressController.text.trim();
    final key = _keyController.text.trim();
    final uri = Uri.tryParse(address);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty ||
        key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe o endereço local e a chave do celular transmissor.'),
        ),
      );
      return;
    }

    setState(() => _opening = true);
    final profile = await _settings.initialize();
    final source = VideoSourceConfig(
      type: VideoSourceType.remotePhone,
      remoteBaseUrl: address,
      remoteAccessKey: key,
      displayName: 'Celular remoto',
      analysisInterval: profile.source.analysisInterval,
    );
    await _settings.updateRuntime(source: source);
    if (!mounted) return;
    setState(() => _opening = false);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MonitorScreen(
          initialSource: source,
          settings: profile.settings,
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modo Monitor'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _changeMode,
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Alterar modo'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Este celular vai receber imagem',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Use este modo no aparelho que ficará com a IA, histórico, alertas e áudios personalizados. '
                          'No outro celular, abra Modo Transmissão para enviar a câmera pela rede local.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _scanQr,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Escanear QR do transmissor'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MultiCameraScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.dashboard_customize_outlined),
                    label: const Text('Abrir Central multicâmera'),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _addressController,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Endereço do celular transmissor',
                      hintText: 'http://192.168.0.20:8766',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _keyController,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Chave de sessão',
                      helperText: 'A chave aparece no Modo Transmissão do outro celular.',
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _opening ? null : _openMonitor,
                    icon: _opening
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: const Text('Receber e analisar'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A análise acontece neste aparelho receptor. O transmissor apenas captura e envia imagem/status.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
      ),
    );
  }
}
