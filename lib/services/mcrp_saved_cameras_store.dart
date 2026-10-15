import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'mcrp_client.dart';

/// Lista opt-in de câmeras Minha Câmera. O token do QR é um segredo:
/// fica somente no armazenamento privado do aplicativo e não é exibido na lista.
class SavedMcrpCamera {
  const SavedMcrpCamera({required this.name, required this.liveUrl});

  final String name;
  final String liveUrl;

  String get networkAddress {
    final uri = McrpAddress.parse(liveUrl).liveUrl;
    return '${uri.host}:${uri.port}';
  }
}

class McrpSavedCamerasStore {
  McrpSavedCamerasStore({Future<Directory> Function()? directoryProvider})
      : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  static const int maximumCameras = 20;
  static const int maximumFileBytes = 32768;
  static const String fileName = 'minha_camera_saved_v1.json';

  final Future<Directory> Function() _directoryProvider;

  Future<File> _file() async {
    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    return File('${directory.path}/$fileName');
  }

  Future<List<SavedMcrpCamera>> load() async {
    final file = await _file();
    if (!await file.exists()) {
      return const [];
    }
    if (await file.length() > maximumFileBytes) {
      throw const FormatException('Cadastro local de câmeras excedeu o limite.');
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List) {
      throw const FormatException('Cadastro local de câmeras inválido.');
    }
    final cameras = <SavedMcrpCamera>[];
    final seen = <String>{};
    for (final item in decoded) {
      if (item is! Map || item['name'] is! String || item['url'] is! String) {
        continue;
      }
      try {
        final uri = McrpAddress.parse(item['url'] as String).liveUrl.toString();
        final name = _validName(item['name'] as String);
        if (seen.add(uri)) {
          cameras.add(SavedMcrpCamera(name: name, liveUrl: uri));
        }
      } on FormatException {
        // Ignora registros antigos inválidos e nunca reconecta URLs arbitrárias.
      }
      if (cameras.length == maximumCameras) {
        break;
      }
    }
    return cameras;
  }

  Future<List<SavedMcrpCamera>> save({required String name, required String liveUrl}) async {
    final normalized = McrpAddress.parse(liveUrl).liveUrl.toString();
    final label = _validName(name);
    final existing = await load();
    final updated = <SavedMcrpCamera>[
      SavedMcrpCamera(name: label, liveUrl: normalized),
      ...existing.where((camera) => camera.liveUrl != normalized),
    ].take(maximumCameras).toList();
    await _write(updated);
    return updated;
  }

  Future<List<SavedMcrpCamera>> remove(String liveUrl) async {
    final normalized = McrpAddress.parse(liveUrl).liveUrl.toString();
    final updated = (await load())
        .where((camera) => camera.liveUrl != normalized)
        .toList();
    await _write(updated);
    return updated;
  }

  Future<void> _write(List<SavedMcrpCamera> cameras) async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    final data = jsonEncode([
      for (final camera in cameras) {'name': camera.name, 'url': camera.liveUrl},
    ]);
    try {
      await temp.writeAsString(data, flush: true);
      await temp.rename(file.path);
    } finally {
      if (await temp.exists()) {
        await temp.delete();
      }
    }
  }

  static String _validName(String input) {
    final name = input.trim();
    if (name.isEmpty || name.length > 48 ||
        name.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
      throw const FormatException('Nome da câmera deve ter entre 1 e 48 caracteres.');
    }
    return name;
  }
}
