import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/bike_mode_config.dart';
import 'error_log_service.dart';

class BikeModeService extends ChangeNotifier {
  BikeModeService._();

  static final BikeModeService instance = BikeModeService._();

  final ErrorLogService _logs = ErrorLogService.instance;
  BikeModeConfig _config = const BikeModeConfig();
  bool _initialized = false;
  File? _file;

  BikeModeConfig get config => _config;

  Future<BikeModeConfig> initialize() async {
    if (_initialized) return _config;
    final root = await getApplicationSupportDirectory();
    _file = File('${root.path}${Platform.pathSeparator}bike_mode.json');
    final file = _file!;
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          _config = BikeModeConfig.fromJson(decoded.cast<String, dynamic>());
        }
      } catch (error, stackTrace) {
        await _logs.recordException(
          source: 'Modo Bike',
          error: error,
          stackTrace: stackTrace,
          message: 'Falha ao carregar o Modo Bike; usando configuração segura.',
          level: ErrorLogLevel.warning,
        );
      }
    }
    _initialized = true;
    return _config;
  }

  Future<void> save(BikeModeConfig config) async {
    await initialize();
    _config = config;
    final file = _file!;
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(config.toJson()), flush: true);
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
    notifyListeners();
  }
}
