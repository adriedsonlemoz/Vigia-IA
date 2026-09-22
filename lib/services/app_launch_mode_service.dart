import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'error_log_service.dart';

enum AppLaunchMode {
  normal,
  monitor,
  bike,
  transmission;

  static AppLaunchMode? parse(String? value) {
    for (final mode in values) {
      if (mode.name == value) return mode;
    }
    return null;
  }
}

class AppLaunchModeService extends ChangeNotifier {
  AppLaunchModeService._();

  static final AppLaunchModeService instance = AppLaunchModeService._();

  final ErrorLogService _logs = ErrorLogService.instance;
  AppLaunchMode? _mode;
  bool _initialized = false;
  File? _file;

  AppLaunchMode? get mode => _mode;

  Future<AppLaunchMode?> initialize() async {
    if (_initialized) return _mode;
    final root = await getApplicationSupportDirectory();
    _file = File('${root.path}${Platform.pathSeparator}launch_mode.json');
    final file = _file!;
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          _mode = AppLaunchMode.parse(decoded['mode'] as String?);
        }
      } catch (error, stackTrace) {
        await _logs.recordException(
          source: 'Modo inicial',
          error: error,
          stackTrace: stackTrace,
          message: 'Falha ao carregar o modo inicial; pedindo nova escolha.',
          level: ErrorLogLevel.warning,
        );
      }
    }
    _initialized = true;
    return _mode;
  }

  Future<void> save(AppLaunchMode mode) async {
    await initialize();
    _mode = mode;
    final file = _file!;
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode(<String, Object?>{
        'version': 1,
        'mode': mode.name,
      }),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
    notifyListeners();
  }
}
