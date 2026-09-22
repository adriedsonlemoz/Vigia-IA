import 'package:flutter/material.dart';

import '../core/app_metadata.dart';
import '../services/export_preferences_service.dart';
import 'access_guide_screen.dart';
import 'advanced_settings_screen.dart';
import 'audio_settings_screen.dart';
import 'alerts_clips_screen.dart';
import 'app_info_screen.dart';
import 'appearance_settings_screen.dart';
import 'bike_mode_screen.dart';
import 'camera_mode_screen.dart';
import 'error_center_screen.dart';
import 'esp32_settings_screen.dart';
import 'launch_mode_screen.dart';
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

  Future<void> _configureExportDestination(BuildContext context) async {
    final service = ExportPreferencesService.instance;
    final current = await service.initialize();
    if (!context.mounted) return;
    final selected = await showDialog<ExportDestinationPreference>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Local padrão de exportação'),
        children: ExportDestinationPreference.values
            .map(
              (value) => ListTile(
                leading: Icon(
                  value == current
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                ),
                title: Text(value.label),
                subtitle: Text(
                  value == ExportDestinationPreference.downloads
                      ? 'Salva automaticamente em Downloads/Vigia IA.'
                      : 'Abre o seletor do Android em cada exportação.',
                ),
                onTap: () => Navigator.pop(dialogContext, value),
              ),
            )
            .toList(growable: false),
      ),
    );
    if (selected == null) return;
    await service.setDestination(selected);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exportações: ${selected.label}.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final left = <Widget>[
      _CategoryCard(
        icon: Icons.tune_rounded,
        title: 'Preferências',
        subtitle: 'Áudio, aparência e opções gerais do aplicativo.',
        children: [
          _SettingsTile(
            icon: Icons.library_music_outlined,
            title: 'Áudios e voz',
            subtitle: 'Ouça, troque, grave ou restaure os áudios do Vigia IA.',
            onTap: () => _push(context, const AudioSettingsScreen()),
          ),
          _SettingsTile(
            icon: Icons.color_lens_outlined,
            title: 'Tema e cores',
            subtitle: 'Sistema, Claro ou Escuro; Turquesa, Azul, Roxo ou Laranja.',
            onTap: () => _push(context, const AppearanceSettingsScreen()),
          ),
        ],
      ),
      _CategoryCard(
        icon: Icons.radar_rounded,
        title: 'Monitoramento',
        subtitle: 'Modo, fontes, ESP32 e perfis de monitoramento.',
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
            icon: Icons.dashboard_customize_outlined,
            title: 'Alterar modo agora',
            subtitle: 'Abra a seleção de Normal, Monitor, Bike ou Transmissão sem apagar dados.',
            onTap: () => _push(
              context,
              const LaunchModeScreen(manualReview: true),
            ),
          ),
          _SettingsTile(
            icon: Icons.directions_bike_outlined,
            title: 'Modo Bike',
            subtitle: 'Configure energia, sensores e simulação da bike.',
            onTap: () => _push(context, const BikeModeScreen()),
          ),
          _SettingsTile(
            icon: Icons.memory_rounded,
            title: 'ESP32 e sensores',
            subtitle: 'Conecte o módulo, calibre sensores e prepare a câmera ESP32.',
            onTap: () => _push(context, const Esp32SettingsScreen()),
          ),
          _SettingsTile(
            icon: Icons.video_settings_outlined,
            title: 'Multicâmera',
            subtitle: 'Cadastre câmera local, RTSP e celulares remotos.',
            onTap: () => _push(context, const MultiCameraScreen()),
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
    ];

    final right = <Widget>[
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
            icon: Icons.download_outlined,
            title: 'Local padrão de exportação',
            subtitle: 'Downloads por padrão ou perguntar onde salvar.',
            onTap: () => _configureExportDestination(context),
          ),
          _SettingsTile(
            icon: Icons.query_stats_outlined,
            title: 'Estatísticas',
            subtitle: 'Resumo por período, câmera, área e horário.',
            onTap: () => _push(context, const StatisticsScreen()),
          ),
        ],
      ),
      _CategoryCard(
        icon: Icons.settings_suggest_outlined,
        title: 'Sistema',
        subtitle: 'Saúde, permissões e estado do aparelho.',
        children: [
          _SettingsTile(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Permissões do aplicativo',
            subtitle: 'Revise câmera, notificações e rede local sem repetir o onboarding.',
            onTap: () => _push(
              context,
              const AccessGuideScreen(manualReview: true),
            ),
          ),
          _SettingsTile(
            icon: Icons.monitor_heart_outlined,
            title: 'Saúde do sistema',
            subtitle: 'Câmera, IA, FPS, bateria, temperatura, memória e segundo plano.',
            onTap: () => _push(context, const SystemHealthScreen()),
          ),
          _SettingsTile(
            icon: Icons.memory_outlined,
            title: 'Ajustes avançados da IA',
            subtitle: 'Confiança, intervalo da IA, repetição e outros parâmetros técnicos.',
            onTap: () => _push(context, const AdvancedSettingsScreen()),
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
            subtitle: 'Falhas e registros técnicos ficam separados do Histórico.',
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
    ];

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 840) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(18, 12, 9, 28),
                          children: left,
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(9, 12, 18, 28),
                          children: right,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                  children: [...left, ...right],
                ),
              ),
            );
          },
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
