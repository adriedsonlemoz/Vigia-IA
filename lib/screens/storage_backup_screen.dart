import 'dart:async';

import 'package:flutter/material.dart';

import '../models/storage_policy.dart';
import '../models/video_source_config.dart';
import '../services/app_settings_service.dart';
import '../services/backup_export_service.dart';
import '../services/storage_management_service.dart';
import '../utils/storage_size_formatter.dart';
import '../widgets/help_button.dart';

class StorageBackupScreen extends StatefulWidget {
  const StorageBackupScreen({super.key});

  @override
  State<StorageBackupScreen> createState() => _StorageBackupScreenState();
}

class _StorageBackupScreenState extends State<StorageBackupScreen> {
  final _settings = AppSettingsService.instance;
  final _storage = const StorageManagementService();
  final _backup = const BackupExportService();
  PersistedMonitorProfile? _profile;
  StorageUsage? _usage;
  late StoragePolicy _policy;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final profile = await _settings.initialize();
    final usage = await _storage.usage();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _policy = profile.settings.storagePolicy;
      _usage = usage;
    });
  }

  Future<void> _savePolicy() async {
    final current = _profile;
    if (current == null) return;
    final next = PersistedMonitorProfile(source: current.source, settings: current.settings.copyWith(storagePolicy: _policy));
    await _settings.saveProfile(next);
    _profile = next;
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Política de armazenamento salva.')));
  }

  Future<void> _cleanup() async {
    setState(() => _busy = true);
    final removed = await _storage.cleanup(_policy);
    final usage = await _storage.usage();
    if (!mounted) return;
    setState(() { _usage = usage; _busy = false; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$removed evento(s) antigo(s) removido(s).')));
  }

  Future<void> _run(Future<String> Function() operation, String success) async {
    setState(() => _busy = true);
    try {
      final path = await operation();
      if (!mounted) return;
      showDialog<void>(context: context, builder: (_) => AlertDialog(title: Text(success), content: SelectableText(path), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    List<String> backups;
    try {
      backups = await _backup.listSettingsBackups();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (backups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum backup local foi encontrado.')),
      );
      return;
    }
    final path = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Escolha um backup'),
        children: backups
            .take(12)
            .map(
              (item) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.restore_rounded),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_backupName(item))),
                    ],
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
    if (path == null) return;
    setState(() => _busy = true);
    try {
      await _backup.restoreSettingsBackup(path);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações restauradas.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível restaurar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _backupName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final name = normalized.split('/').last;
    return name
        .replaceFirst('monitor_backup_', '')
        .replaceFirst('.json', '')
        .replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    if (_profile == null || _usage == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Armazenamento e backup'),
        actions: const [
          HelpButton(
            title: 'Armazenamento e backup',
            message: 'Veja quanto espaço o Vigia IA usa, defina o limite de fotos e vídeos e crie backups ou exportações locais.',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [const Icon(Icons.storage_rounded), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(StorageSizeFormatter.formatBytes(_usage!.mediaBytes), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), Text('${_usage!.files} arquivo(s) de histórico e mídia', style: Theme.of(context).textTheme.bodySmall)]))]))),
          const SizedBox(height: 12),
          SwitchListTile(value: _policy.autoCleanup, onChanged: (v) => setState(() => _policy = _policy.copyWith(autoCleanup: v)), title: const Text('Limpeza automática', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Remove eventos antigos respeitando retenção e limite de espaço.')),
          _slider('Reter por', '${_policy.retentionDays} dias', _policy.retentionDays.toDouble(), 1, 365, (v) => setState(() => _policy = _policy.copyWith(retentionDays: v.round()))),
          _slider('Limite para fotos e vídeos', StorageSizeFormatter.formatMebibytes(_policy.maxStorageMb), _policy.maxStorageMb.toDouble(), 128, 4096, (v) => setState(() => _policy = _policy.copyWith(maxStorageMb: v.round()))),
          Row(children: [Expanded(child: FilledButton.icon(onPressed: _busy ? null : _savePolicy, icon: const Icon(Icons.save_outlined), label: const Text('Salvar'))), const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : _cleanup, icon: const Icon(Icons.cleaning_services_outlined), label: const Text('Limpar agora')))]),
          const SizedBox(height: 22),
          const Text('Backup e exportação', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          const Text('Os arquivos são criados localmente na pasta de documentos do aplicativo.'),
          const SizedBox(height: 10),
          _Action(icon: Icons.backup_outlined, title: 'Criar backup das configurações', subtitle: 'Salva regras, áreas, agenda, presets e preferências. Credenciais ficam fora do backup portátil.', onTap: _busy ? null : () => _run(_backup.createSettingsBackup, 'Backup criado')),
          _Action(icon: Icons.restore_rounded, title: 'Restaurar configurações', subtitle: 'Escolha um dos backups locais criados pelo aplicativo.', onTap: _busy ? null : _restore),
          _Action(icon: Icons.file_download_outlined, title: 'Exportar eventos', subtitle: 'Cria pasta com eventos.json, fotos e vídeos associados.', onTap: _busy ? null : () => _run(_backup.exportEvents, 'Eventos exportados')),
        ],
      ),
    );
  }

  Widget _slider(String title, String value, double current, double min, double max, ValueChanged<double> onChanged) => Card(child: Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 8), child: Column(children: [Row(children: [Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))), Text(value, style: const TextStyle(fontWeight: FontWeight.w900))]), Slider(value: current.clamp(min, max).toDouble(), min: min, max: max, divisions: ((max - min) ~/ (max > 1000 ? 64 : 1)).clamp(1, 364).toInt(), onChanged: onChanged)])));
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon; final String title; final String subtitle; final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(enabled: onTap != null, onTap: onTap, leading: Icon(icon), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right_rounded)));
}
