import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_launch_mode_service.dart';
import 'bike_mode_screen.dart';
import 'camera_mode_screen.dart';
import 'home_screen.dart';
import 'monitor_connect_screen.dart';

class LaunchModeScreen extends StatefulWidget {
  const LaunchModeScreen({
    super.key,
    this.startMonitorOnLoad = false,
    this.manualReview = false,
  });

  final bool startMonitorOnLoad;
  final bool manualReview;

  @override
  State<LaunchModeScreen> createState() => _LaunchModeScreenState();
}

class _LaunchModeScreenState extends State<LaunchModeScreen> {
  final AppLaunchModeService _service = AppLaunchModeService.instance;
  AppLaunchMode? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final mode = await _service.initialize();
    if (!mounted) return;
    setState(() => _selected = mode);
  }

  Future<void> _select(AppLaunchMode mode) async {
    if (_saving) return;
    setState(() {
      _selected = mode;
      _saving = true;
    });
    await _service.save(mode);
    if (!mounted) return;
    setState(() => _saving = false);
    if (widget.manualReview) {
      Navigator.of(context).pop(mode);
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => _screenFor(mode)),
    );
  }

  Widget _screenFor(AppLaunchMode mode) => switch (mode) {
        AppLaunchMode.normal => HomeScreen(
            startMonitorOnLoad: widget.startMonitorOnLoad,
          ),
        AppLaunchMode.monitor => const MonitorConnectScreen(),
        AppLaunchMode.bike => const BikeModeScreen(),
        AppLaunchMode.transmission => const CameraModeScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.manualReview,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Escolha o modo', style: TextStyle(fontWeight: FontWeight.w900)),
            Text(
              'Você pode alterar depois nas configurações',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Como este celular vai trabalhar agora?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Escolha o papel deste aparelho. Um celular pode enviar imagem, outro pode receber e analisar, ou este mesmo aparelho pode fazer tudo sozinho.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _LaunchModeCard(
              icon: Icons.shield_outlined,
              title: 'Modo normal',
              subtitle:
                  'Este celular vai usar a própria câmera e analisar a imagem no próprio aparelho.',
              selected: selected == AppLaunchMode.normal,
              busy: _saving && selected == AppLaunchMode.normal,
              onTap: () => _select(AppLaunchMode.normal),
            ),
            const SizedBox(height: 10),
            _LaunchModeCard(
              icon: Icons.cast_connected_rounded,
              title: 'Modo Monitor',
              subtitle:
                  'Este celular vai receber imagem de outro aparelho e fazer a IA, histórico, alertas e áudios.',
              selected: selected == AppLaunchMode.monitor,
              busy: _saving && selected == AppLaunchMode.monitor,
              onTap: () => _select(AppLaunchMode.monitor),
            ),
            const SizedBox(height: 10),
            _LaunchModeCard(
              icon: Icons.directions_bike_rounded,
              title: 'Modo Bike',
              subtitle:
                  'Modo próprio da bike. Ao usar câmera remota, este aparelho segue a lógica do receptor: recebe e analisa.',
              selected: selected == AppLaunchMode.bike,
              busy: _saving && selected == AppLaunchMode.bike,
              onTap: () => _select(AppLaunchMode.bike),
            ),
            const SizedBox(height: 10),
            _LaunchModeCard(
              icon: Icons.wifi_tethering_rounded,
              title: 'Modo transmissão',
              subtitle:
                  'Este celular vai enviar imagem pela rede local. No outro celular, escolha Modo Monitor para receber.',
              selected: selected == AppLaunchMode.transmission,
              busy: _saving && selected == AppLaunchMode.transmission,
              onTap: () => _select(AppLaunchMode.transmission),
            ),
            const SizedBox(height: 16),
            Text(
              'O futuro mini mapa/GPS ficará no aparelho receptor. '
              'O transmissor deve continuar leve, enviando imagem e status.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _LaunchModeCard extends StatelessWidget {
  const _LaunchModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.55)
          : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected
              ? scheme.primary.withValues(alpha: 0.55)
              : scheme.outline.withValues(alpha: 0.20),
          width: selected ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: scheme.primary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (busy)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              else
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
