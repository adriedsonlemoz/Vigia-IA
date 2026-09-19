import 'package:flutter/material.dart';

import '../core/app_metadata.dart';
import 'advanced_settings_screen.dart';
import 'alerts_clips_screen.dart';
import 'app_info_screen.dart';
import 'appearance_settings_screen.dart';
import 'bike_mode_screen.dart';
import 'camera_mode_screen.dart';
import 'error_center_screen.dart';
import 'multi_camera_screen.dart';
import 'presets_screen.dart';
import 'statistics_screen.dart';
import 'storage_backup_screen.dart';
import 'system_health_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _openInfo(BuildContext context, AppInfoSection section) {
    _push(context, AppInfoScreen(initialSection: section));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Configurações', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Tudo organizado em um só lugar', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
              children: [
                _CategoryCard(
                  icon: Icons.radar_rounded,
                  title: 'Monitoramento',
                  subtitle: 'Câmeras, modos e perfis de monitoramento.',
                  children: [
                    _SettingsTile(
                      icon: Icons.auto_awesome_motion_outlined,
                      title: 'Presets',
                      subtitle: 'Casa, Ausente, Noite e Personalizado.',
                      onTap: () => _push(context, const PresetsScreen()),
                    ),
                    _SettingsTile(
                      icon: Icons.video_camera_front_outlined,
                      title: 'Modo Câmera',
                      subtitle: 'Use este celular como câmera na rede local.',
                      onTap: () => _push(context, const CameraModeScreen()),
                    ),
                    _SettingsTile(
                      icon: Icons.video_settings_outlined,
                      title: 'Multicâmera',
                      subtitle: 'Cadastre câmera local, RTSP e celulares remotos. Adicionar câmeras não ativa contagem.',
                      onTap: () => _push(context, const MultiCameraScreen()),
                    ),
                    _SettingsTile(
                      icon: Icons.directions_bike_rounded,
                      title: 'Modo Bike',
                      subtitle: 'Economia para o celular traseiro e base do painel remoto.',
                      onTap: () => _push(context, const BikeModeScreen()),
                    ),
                  ],
                ),
                _CategoryCard(
                  icon: Icons.notifications_active_outlined,
                  title: 'Alertas',
                  subtitle: 'Voz, notificações, clipes e mensagens.',
                  children: [
                    _SettingsTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'Alertas e clipes',
                      subtitle: 'Configure voz, som, vibração, notificações e gravações locais.',
                      onTap: () => _push(context, const AlertsClipsScreen()),
                    ),
                  ],
                ),
                _CategoryCard(
                  icon: Icons.palette_outlined,
                  title: 'Aparência',
                  subtitle: 'Tema claro/escuro e cor principal.',
                  children: [
                    _SettingsTile(
                      icon: Icons.color_lens_outlined,
                      title: 'Tema e cores',
                      subtitle: 'Sistema, Claro ou Escuro; Turquesa, Azul, Roxo ou Laranja.',
                      onTap: () => _push(context, const AppearanceSettingsScreen()),
                    ),
                  ],
                ),
                _CategoryCard(
                  icon: Icons.storage_outlined,
                  title: 'Armazenamento',
                  subtitle: 'Histórico, espaço, limpeza, backup e estatísticas.',
                  children: [
                    _SettingsTile(
                      icon: Icons.storage_outlined,
                      title: 'Armazenamento e backup',
                      subtitle: 'Retenção, limite, limpeza, backup e exportação.',
                      onTap: () => _push(context, const StorageBackupScreen()),
                    ),
                    _SettingsTile(
                      icon: Icons.query_stats_outlined,
                      title: 'Estatísticas',
                      subtitle: 'Resumo dos registros por período, câmera, área e horário.',
                      onTap: () => _push(context, const StatisticsScreen()),
                    ),
                  ],
                ),
                _CategoryCard(
                  icon: Icons.settings_suggest_outlined,
                  title: 'Sistema',
                  subtitle: 'Saúde do monitoramento e estado do aparelho.',
                  children: [
                    _SettingsTile(
                      icon: Icons.monitor_heart_outlined,
                      title: 'Saúde do sistema',
                      subtitle: 'Câmera, IA, FPS, bateria, temperatura, memória e segundo plano.',
                      onTap: () => _push(context, const SystemHealthScreen()),
                    ),
                  ],
                ),
                _CategoryCard(
                  icon: Icons.health_and_safety_outlined,
                  title: 'Diagnóstico',
                  subtitle: 'Erros, avisos, conexão e ocorrências técnicas.',
                  children: [
                    _SettingsTile(
                      icon: Icons.bug_report_outlined,
                      title: 'Abrir Diagnóstico',
                      subtitle: 'Câmera obstruída/deslocada, falhas e registros técnicos ficam aqui, separados do Histórico.',
                      onTap: () => _push(context, const ErrorCenterScreen()),
                    ),
                  ],
                ),
                _CategoryCard(
                  icon: Icons.info_outline_rounded,
                  title: 'Sobre',
                  subtitle: '${AppMetadata.name} · ${AppMetadata.version}+${AppMetadata.build}',
                  children: [
                    _SettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: 'Sobre o aplicativo',
                      subtitle: 'Versão, desenvolvedor e informações do projeto.',
                      onTap: () => _openInfo(context, AppInfoSection.about),
                    ),
                    _SettingsTile(
                      icon: Icons.history_rounded,
                      title: 'Mudanças',
                      subtitle: 'Novidades e alterações das versões recentes.',
                      onTap: () => _openInfo(context, AppInfoSection.changes),
                    ),
                    _SettingsTile(
                      icon: Icons.volunteer_activism_outlined,
                      title: 'Doações',
                      subtitle: 'PIX: ${AppMetadata.pixKey}',
                      onTap: () => _openInfo(context, AppInfoSection.donations),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _CategoryCard(
                  icon: Icons.tune_rounded,
                  title: 'Avançado',
                  subtitle: 'Parâmetros técnicos da IA, separados das telas principais.',
                  initiallyExpanded: false,
                  children: [
                    _SettingsTile(
                      icon: Icons.memory_outlined,
                      title: 'Ajustes avançados da IA',
                      subtitle: 'Confiança mínima, intervalo da IA, repetição de alertas e parâmetros técnicos.',
                      onTap: () => _push(context, const AdvancedSettingsScreen()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: scheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        children: children,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      );
}
