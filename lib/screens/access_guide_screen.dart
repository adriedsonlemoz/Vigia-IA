import 'dart:async';

import 'package:flutter/material.dart';

import '../services/native_platform_service.dart';
import 'home_screen.dart';

class AccessGuideScreen extends StatefulWidget {
  const AccessGuideScreen({
    super.key,
    this.startMonitorOnLoad = false,
    this.manualReview = false,
  });

  final bool startMonitorOnLoad;
  final bool manualReview;

  @override
  State<AccessGuideScreen> createState() => _AccessGuideScreenState();
}

class _AccessGuideScreenState extends State<AccessGuideScreen> {
  final NativePlatformService _native = NativePlatformService.instance;

  CameraPermissionStatus? _camera;
  LocalNetworkPermissionStatus? _localNetwork;
  bool? _notificationsAllowed;
  bool _loading = true;
  bool _requestingCamera = false;
  bool _requestingNetwork = false;
  bool _requestingNotifications = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final results = await Future.wait<Object>([
      _native.cameraPermissionStatus(),
      _native.localNetworkPermissionStatus(),
      _native.notificationsAllowed(),
    ]);
    if (!mounted) return;
    setState(() {
      _camera = results[0] as CameraPermissionStatus;
      _localNetwork = results[1] as LocalNetworkPermissionStatus;
      _notificationsAllowed = results[2] as bool;
      _loading = false;
    });
  }

  Future<void> _requestCamera() async {
    setState(() => _requestingCamera = true);
    await _native.requestCameraPermission();
    if (!mounted) return;
    setState(() => _requestingCamera = false);
    await _refresh();
  }

  Future<void> _requestLocalNetwork() async {
    setState(() => _requestingNetwork = true);
    await _native.requestLocalNetworkPermission();
    if (!mounted) return;
    setState(() => _requestingNetwork = false);
    await _refresh();
  }

  Future<void> _requestNotifications() async {
    setState(() => _requestingNotifications = true);
    await _native.requestNotificationPermission();
    if (!mounted) return;
    setState(() => _requestingNotifications = false);
    await _refresh();
  }

  Future<void> _continue() async {
    if (widget.manualReview) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final marked = await _native.markOnboardingCompleted();
    if (!mounted) return;
    if (!marked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível concluir o acesso inicial. Tente novamente.'),
        ),
      );
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => HomeScreen(startMonitorOnLoad: widget.startMonitorOnLoad),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final camera = _camera;
    final localNetwork = _localNetwork;
    final notificationsAllowed = _notificationsAllowed;
    final permissionsReady = (camera?.granted ?? false);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Acesso inicial', style: TextStyle(fontWeight: FontWeight.w800)),
            Text(
              'Permissões e configuração rápida',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        colors: [
                          scheme.primary.withValues(alpha: 0.18),
                          scheme.secondary.withValues(alpha: 0.08),
                          scheme.surface,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: scheme.primary.withValues(alpha: 0.20)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.security_rounded, color: scheme.primary),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Antes de usar o Vigia IA',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Algumas permissões são necessárias para a câmera, os alertas e a conexão com outro aparelho. '
                          'Você pode liberar agora ou ajustar depois nas configurações do Android.',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _GuideChip(
                                icon: Icons.videocam_outlined,
                                text: permissionsReady ? 'Câmera pronta' : 'Câmera pendente',
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _GuideChip(
                                icon: Icons.notifications_active_outlined,
                                text: notificationsAllowed == true
                                    ? 'Alertas habilitados'
                                    : 'Alertas recomendados',
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: _GuideChip(
                                icon: Icons.qr_code_scanner_rounded,
                                text: 'Pareamento por QR',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PermissionCard(
                    icon: Icons.videocam_outlined,
                    title: 'Câmera',
                    requiredLabel: 'Obrigatória',
                    description:
                        'Necessária para usar a câmera deste aparelho, escanear QR de outro celular e abrir o monitor.',
                    statusText: camera?.granted == true ? 'Permitida' : 'Não permitida',
                    statusOk: camera?.granted == true,
                    actionLabel: camera?.granted == true
                        ? 'Conferir ajustes'
                        : (camera?.canRequest ?? false)
                            ? 'Permitir agora'
                            : 'Abrir ajustes',
                    onAction: camera?.granted == true
                        ? _native.openAppSettings
                        : (camera?.canRequest ?? false)
                            ? _requestCamera
                            : _native.openAppSettings,
                    busy: _requestingCamera,
                    footer: const Text(
                      'Android: Configurações > Apps > Vigia IA > Permissões > Câmera.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PermissionCard(
                    icon: Icons.notifications_active_outlined,
                    title: 'Notificações',
                    requiredLabel: 'Recomendada',
                    description:
                        'Mantém os avisos visíveis, especialmente quando o monitor ficar em segundo plano.',
                    statusText: notificationsAllowed == true ? 'Permitidas' : 'Ainda não liberadas',
                    statusOk: notificationsAllowed == true,
                    actionLabel: notificationsAllowed == true ? 'Conferir ajustes' : 'Permitir agora',
                    onAction: notificationsAllowed == true
                        ? _native.openAppSettings
                        : _requestNotifications,
                    busy: _requestingNotifications,
                    footer: const Text(
                      'Se o Android bloquear a janela de pedido, use Ajustes do app para liberar manualmente.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PermissionCard(
                    icon: Icons.wifi_tethering_rounded,
                    title: 'Rede local e dispositivos próximos',
                    requiredLabel: localNetwork?.required == true ? 'Importante' : 'Opcional',
                    description:
                        'Usada para conectar outro celular, transmitir pela rede local e descobrir o QR do aparelho remoto.',
                    statusText: localNetwork?.required == true
                        ? (localNetwork?.granted == true ? 'Permitida' : 'Pendente')
                        : 'Só necessária em alguns aparelhos',
                    statusOk: localNetwork?.required != true || localNetwork?.granted == true,
                    actionLabel: localNetwork?.required == true && localNetwork?.granted != true
                        ? (localNetwork?.canRequest ?? true)
                            ? 'Permitir agora'
                            : 'Abrir ajustes'
                        : 'Conferir ajustes',
                    onAction: localNetwork?.required == true && localNetwork?.granted != true
                        ? (localNetwork?.canRequest ?? true)
                            ? _requestLocalNetwork
                            : _native.openAppSettings
                        : _native.openAppSettings,
                    busy: _requestingNetwork,
                    footer: const Text(
                      'No Android a nomenclatura pode variar: rede local, dispositivos próximos ou aparelhos próximos.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.tips_and_updates_outlined),
                            SizedBox(width: 8),
                            Text(
                              'Como ajustar depois',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Text('• Se a câmera não abrir, revise a permissão da câmera.'),
                        SizedBox(height: 6),
                        Text('• Se os alertas sumirem, revise notificações e bateria em segundo plano.'),
                        SizedBox(height: 6),
                        Text('• Se o outro celular não conectar, revise rede local/dispositivos próximos.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _continue,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(widget.manualReview ? 'Voltar' : 'Continuar para o app'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Atualizar status das permissões'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _GuideChip extends StatelessWidget {
  const _GuideChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: scheme.primary),
          const SizedBox(width: 4),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.requiredLabel,
    required this.description,
    required this.statusText,
    required this.statusOk,
    required this.actionLabel,
    required this.onAction,
    required this.busy,
    required this.footer,
  });

  final IconData icon;
  final String title;
  final String requiredLabel;
  final String description;
  final String statusText;
  final bool statusOk;
  final String actionLabel;
  final FutureOr<void> Function() onAction;
  final bool busy;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(description),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _PermissionStateBadge(label: requiredLabel, ok: statusOk),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                statusOk ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: statusOk ? Colors.green : scheme.error,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: busy ? null : () => onAction(),
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.settings_outlined),
              label: Text(actionLabel),
            ),
          ),
          const SizedBox(height: 10),
          footer,
        ],
      ),
    );
  }
}

class _PermissionStateBadge extends StatelessWidget {
  const _PermissionStateBadge({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (ok ? scheme.primary : scheme.error).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: ok ? scheme.primary : scheme.error,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
