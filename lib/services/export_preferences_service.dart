import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

enum ExportDestinationPreference {
  downloads,
  askEveryTime;

  String get label => switch (this) {
        ExportDestinationPreference.downloads => 'Downloads',
        ExportDestinationPreference.askEveryTime => 'Perguntar sempre',
      };
}

class ExportPreferencesService {
  ExportPreferencesService._();

  static final ExportPreferencesService instance =
      ExportPreferencesService._();

  ExportDestinationPreference _destination =
      ExportDestinationPreference.downloads;
  bool _initialized = false;
  File? _file;

  ExportDestinationPreference get destination => _destination;

  Future<ExportDestinationPreference> initialize() async {
    if (_initialized) return _destination;
    final root = await getApplicationSupportDirectory();
    _file = File(
      '${root.path}${Platform.pathSeparator}export_preferences.json',
    );
    final file = _file!;
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          final raw = decoded['destination']?.toString();
          _destination = ExportDestinationPreference.values.firstWhere(
            (value) => value.name == raw,
            orElse: () => ExportDestinationPreference.downloads,
          );
        }
      } catch (_) {
        _destination = ExportDestinationPreference.downloads;
      }
    }
    _initialized = true;
    return _destination;
  }

  Future<void> setDestination(ExportDestinationPreference value) async {
    await initialize();
    _destination = value;
    final file = _file!;
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode(<String, Object?>{
        'version': 1,
        'destination': value.name,
      }),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }
}
