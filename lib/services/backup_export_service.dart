import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'app_settings_service.dart';
import 'event_history_service.dart';

class BackupExportService {
  const BackupExportService();

  Future<String> createSettingsBackup() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}${Platform.pathSeparator}exports');
    await dir.create(recursive: true);
    final stamp = _stamp(DateTime.now());
    final file = File('${dir.path}${Platform.pathSeparator}monitor_backup_$stamp.json');
    final payload = await AppSettingsService.instance.exportPortableProfile();
    await file.writeAsString(jsonEncode(<String, Object?>{
      'schema': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'profile': payload,
    }), flush: true);
    return file.path;
  }

  Future<void> restoreSettingsBackup(String path) async {
    final decoded = jsonDecode(await File(path).readAsString());
    if (decoded is! Map) throw const FormatException('Backup inválido.');
    final profile = (decoded['profile'] as Map?)?.cast<String, dynamic>();
    if (profile == null) throw const FormatException('Perfil não encontrado no backup.');
    await AppSettingsService.instance.importPortableProfile(profile);
  }

  Future<List<String>> listSettingsBackups() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}${Platform.pathSeparator}exports');
    if (!await dir.exists()) return const <String>[];
    final files = <File>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && entity.path.endsWith('.json') && entity.path.split(Platform.pathSeparator).last.startsWith('monitor_backup_')) {
        files.add(entity);
      }
    }
    files.sort((a, b) => b.path.compareTo(a.path));
    return files.map((file) => file.path).toList(growable: false);
  }

  Future<String> exportEvents({DateTime? since}) async {
    final history = EventHistoryService.instance;
    await history.initialize();
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}${Platform.pathSeparator}exports${Platform.pathSeparator}eventos_${_stamp(DateTime.now())}');
    await dir.create(recursive: true);
    final mediaDir = Directory('${dir.path}${Platform.pathSeparator}midia');
    await mediaDir.create(recursive: true);
    final exported = <Map<String, Object?>>[];
    for (final event in history.events.where((event) => since == null || !event.createdAt.isBefore(since))) {
      final item = Map<String, Object?>.from(event.toJson());
      item['snapshotPath'] = await _copyMedia(event.snapshotPath, mediaDir);
      item['clipPath'] = await _copyMedia(event.clipPath, mediaDir);
      exported.add(item);
    }
    await File('${dir.path}${Platform.pathSeparator}eventos.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(exported),
      flush: true,
    );
    return dir.path;
  }

  Future<String?> _copyMedia(String? path, Directory destination) async {
    if (path == null || path.isEmpty) return null;
    final source = File(path);
    if (!await source.exists()) return null;
    final name = path.split(Platform.pathSeparator).last;
    final target = File('${destination.path}${Platform.pathSeparator}$name');
    await source.copy(target.path);
    return 'midia${Platform.pathSeparator}$name';
  }

  String _stamp(DateTime value) => '${value.year.toString().padLeft(4, '0')}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}_${value.hour.toString().padLeft(2, '0')}${value.minute.toString().padLeft(2, '0')}${value.second.toString().padLeft(2, '0')}';
}
