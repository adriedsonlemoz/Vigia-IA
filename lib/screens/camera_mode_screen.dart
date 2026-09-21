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
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Colors.black,
            child: _server.running
                ? _server.buildPreview()
                : const _CameraStandbyPanel(),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: _CameraModeTopBar(
                  running: _server.running,
                  starting: _server.starting,
                  onBack: () => Navigator.of(context).maybePop(),
                  onToggle: _toggle,
                ),
              ),
            ),
          ),
          Positioned(
            left: landscape ? null : 0,
            right: 0,
            bottom: 0,
            top: landscape ? 74 : null,
            width: landscape ? 390 : null,
            child: SafeArea(
              top: false,
              left: false,
              child: _CameraModeControlPanel(
                running: _server.running,
                starting: _server.starting,
                error: _server.error,
                bikeModeEnabled: _server.bikeModeEnabled,
                bikePowerProfileLabel: _server.bikePowerProfileLabel,
                address: address,
                accessKey: _server.accessKey,
                pairingCode: pairingCode,
                showInlineQr: showInlineQr && !landscape,
                onCopyAddress: address == null
                    ? null
                    : () => _copy(address, 'Endereço'),
                onCopyKey: () => _copy(_server.accessKey, 'Chave'),
                onShowQr: pairingCode == null
                    ? null
                    : () => _showPairingQr(pairingCode),
                onToggle: _toggle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraModeTopBar extends StatelessWidget {
  const _CameraModeTopBar({
    required this.running,
    required this.starting,
    required this.onBack,
    required this.onToggle,
  });

  final bool running;
  final bool starting;
  final VoidCallback onBack;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final statusColor = running ? const Color(0xFF69D59C) : Colors.white70;
    return Material(
      color: Colors.black.withValues(alpha: 0.46),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Sair do Modo Câmera',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 9),
            const Expanded(
              child: Text(
                'Modo Câmera',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            if (running)
              TextButton.icon(
                onPressed: starting ? null : onToggle,
                icon: const Icon(Icons.stop_rounded, size: 18),
                label: const Text('Parar'),
              ),
          ],
        ),
      ),
    );
  }
}

class _CameraStandbyPanel extends StatelessWidget {
  const _CameraStandbyPanel();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_camera_front_outlined, size: 58, color: Colors.white),
            SizedBox(height: 12),
            Text(
              'Transmissão desligada',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 6),
            Text(
              'Este aparelho ficará dedicado a enviar imagem pela rede local quando o Modo Câmera for iniciado.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraModeControlPanel extends StatelessWidget {
  const _CameraModeControlPanel({
    required this.running,
    required this.starting,
    required this.error,
    required this.bikeModeEnabled,
    required this.bikePowerProfileLabel,
    required this.address,
    required this.accessKey,
    required this.pairingCode,
    required this.showInlineQr,
    required this.onCopyAddress,
    required this.onCopyKey,
    required this.onShowQr,
    required this.onToggle,
  });

  final bool running;
  final bool starting;
  final String? error;
  final bool bikeModeEnabled;
  final String bikePowerProfileLabel;
  final String? address;
  final String accessKey;
  final String? pairingCode;
  final bool showInlineQr;
  final VoidCallback? onCopyAddress;
  final VoidCallback onCopyKey;
  final VoidCallback? onShowQr;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.92),
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        children: [
          Row(
            children: [
              Icon(
                running
                    ? Icons.wifi_tethering_rounded
                    : Icons.wifi_tethering_off_rounded,
                color: running ? const Color(0xFF4ADE80) : null,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  running
                      ? 'Transmitindo somente na rede local'
                      : 'Servidor local desligado',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: TextStyle(color: scheme.error)),
          ],
          if (bikeModeEnabled) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.directions_bike_rounded, size: 19),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Modo Bike • $bikePowerProfileLabel',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ],
          if (running && address != null) ...[
            const SizedBox(height: 12),
            _CopyRow(label: 'Endereço', value: address!, onCopy: onCopyAddress!),
            const SizedBox(height: 8),
            _CopyRow(label: 'Chave', value: accessKey, onCopy: onCopyKey),
            if (pairingCode != null && showInlineQr) ...[
              const SizedBox(height: 12),
              _InlineQr(pairingCode: pairingCode!),
            ],
            if (pairingCode != null && !showInlineQr) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onShowQr,
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const Text('MOSTRAR QR PARA CONECTAR'),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Não é necessário internet; ambos devem estar no mesmo Wi‑Fi ou hotspot.',
            ),
          ],
          if (running && address == null) ...[
            const SizedBox(height: 10),
            Text(
              'Nenhum endereço IPv4 local foi encontrado. Conecte este aparelho ao mesmo Wi‑Fi ou hotspot do celular que fará o monitoramento.',
              style: TextStyle(color: scheme.error),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: starting ? null : onToggle,
            icon: Icon(running ? Icons.stop_rounded : Icons.play_arrow_rounded),
            label: Text(running ? 'PARAR MODO CÂMERA' : 'INICIAR MODO CÂMERA'),
          ),
        ],
      ),
    );
  }
}

class _InlineQr extends StatelessWidget {
  const _InlineQr({required this.pairingCode});

  final String pairingCode;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  'No outro aparelho, abra Central multicâmera e escaneie este código.',
                ),
                SizedBox(height: 7),
                Text(
                  'O QR contém a chave desta sessão. Use apenas entre seus aparelhos.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
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
