import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/native_platform_service.dart';
import '../services/remote_camera_pairing_service.dart';
import '../services/remote_camera_server_service.dart';
import '../services/system_ui_service.dart';

class CameraModeScreen extends StatefulWidget {
  const CameraModeScreen({super.key});

  @override
  State<CameraModeScreen> createState() => _CameraModeScreenState();
}

class _CameraModeScreenState extends State<CameraModeScreen> {
  final RemoteCameraServerService _server = RemoteCameraServerService.instance;
  final NativePlatformService _native = NativePlatformService.instance;

  @override
  void initState() {
    super.initState();
    unawaited(SystemUiService.immersive());
    _server.addListener(_refresh);
  }

  @override
  void dispose() {
    _server.removeListener(_refresh);
    unawaited(SystemUiService.edgeToEdge());
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _toggle() async {
    if (_server.running) {
      await _server.stop();
      return;
    }

    final cameraGranted = await _native.requestCameraPermission();
    if (!mounted) return;
    if (!cameraGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'A permissão da câmera é necessária para iniciar a transmissão.',
          ),
          action: SnackBarAction(
            label: 'AJUSTES',
            onPressed: () => unawaited(_native.openAppSettings()),
          ),
        ),
      );
      return;
    }

    final localNetworkStatus = await _native.localNetworkPermissionStatus();
    if (localNetworkStatus.required && !localNetworkStatus.granted) {
      final localNetworkGranted = await _native.requestLocalNetworkPermission();
      if (!mounted) return;
      if (!localNetworkGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Permita o acesso à rede local/dispositivos próximos para transmitir para outro celular.',
            ),
            action: SnackBarAction(
              label: 'AJUSTES',
              onPressed: () => unawaited(_native.openAppSettings()),
            ),
          ),
        );
        return;
      }
    }

    final notificationsAllowed = await _native.requestNotificationPermission();
    if (!mounted) return;
    if (!notificationsAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A transmissão pode continuar, mas a notificação permanente pode ficar oculta.',
          ),
        ),
      );
    }

    await _server.start();
    if (!mounted) return;
    if (!_server.running && _server.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_server.error!)),
      );
    }
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copiado.')));
  }

  Future<void> _showPairingQr(String pairingCode) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QR para conectar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 240,
              height: 240,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: QrImageView(
                data: pairingCode,
                backgroundColor: Colors.white,
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Escaneie este código no outro aparelho pela Central multicâmera.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final address = _server.address;
    final pairingCode = _server.running && address != null
        ? RemoteCameraPairingService.encode(
            RemoteCameraPairingData(
              address: address,
              accessKey: _server.accessKey,
              name: 'Vigia IA - celular remoto',
            ),
          )
        : null;
    final showInlineQr = MediaQuery.sizeOf(context).height >= 700;
    return Scaffold(
      appBar: AppBar(title: const Text('Modo Câmera')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.black,
                child: _server.running ? _server.buildPreview() : const Center(child: Icon(Icons.videocam_off_outlined, size: 64)),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(_server.running ? Icons.wifi_tethering_rounded : Icons.wifi_tethering_off_rounded, color: _server.running ? const Color(0xFF4ADE80) : null),
                      const SizedBox(width: 9),
                      Expanded(child: Text(_server.running ? 'Transmitindo somente na rede local' : 'Servidor local desligado', style: const TextStyle(fontWeight: FontWeight.w900))),
                    ],
                  ),
                  if (_server.error != null) ...[
                    const SizedBox(height: 8),
                    Text(_server.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  if (_server.bikeModeEnabled) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.directions_bike_rounded, size: 19),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Modo Bike • ${_server.bikePowerProfileLabel}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_server.running && address != null) ...[
                    const SizedBox(height: 12),
                    _CopyRow(label: 'Endereço', value: address, onCopy: () => _copy(address, 'Endereço')),
                    const SizedBox(height: 8),
                    _CopyRow(label: 'Chave', value: _server.accessKey, onCopy: () => _copy(_server.accessKey, 'Chave')),
                    if (pairingCode != null && showInlineQr) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 142,
                              height: 142,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: QrImageView(
                                data: pairingCode,
                                backgroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Conectar por QR',
                                    style: TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    'No outro aparelho, abra Central multicâmera → Escanear QR e aponte para este código.',
                                  ),
                                  SizedBox(height: 7),
                                  Text(
                                    'O QR contém a chave desta sessão. Use apenas entre seus aparelhos na mesma rede.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (pairingCode != null && !showInlineQr) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => _showPairingQr(pairingCode),
                        icon: const Icon(Icons.qr_code_2_rounded),
                        label: const Text('MOSTRAR QR PARA CONECTAR'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Text('A conexão continua funcionando manualmente pelo endereço e chave. Não é necessário internet; ambos devem estar no mesmo Wi‑Fi ou hotspot.'),
                  ],
                  if (_server.running && address == null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Nenhum endereço IPv4 local foi encontrado. Conecte este aparelho ao mesmo Wi‑Fi ou hotspot do celular que fará o monitoramento.',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _server.starting ? null : _toggle,
                    icon: Icon(_server.running ? Icons.stop_rounded : Icons.play_arrow_rounded),
                    label: Text(_server.running ? 'PARAR MODO CÂMERA' : 'INICIAR MODO CÂMERA'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value, required this.onCopy});
  final String label;
  final String value;
  final VoidCallback onCopy;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.bodySmall), SelectableText(value, style: const TextStyle(fontWeight: FontWeight.w800))])), IconButton(onPressed: onCopy, icon: const Icon(Icons.copy_rounded))]),
      );
}
