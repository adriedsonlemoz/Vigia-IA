import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'services/appearance_settings_service.dart';
import 'services/error_log_service.dart';
import 'services/system_ui_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemUiService.edgeToEdge();
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await ErrorLogService.instance.initialize();
  await AppearanceSettingsService.instance.initialize();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      ErrorLogService.instance.recordException(
        source: 'Flutter',
        error: details.exception,
        stackTrace: details.stack,
        message: 'Erro não tratado pela interface.',
        context: <String, Object?>{
          if (details.context != null)
            'contexto': details.context!.toDescription(),
          'biblioteca': details.library,
        },
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(
      ErrorLogService.instance.recordException(
        source: 'Plataforma',
        error: error,
        stackTrace: stackTrace,
        message: 'Erro não tratado da plataforma.',
      ),
    );
    return true;
  };

  runApp(const VigiaIaApp());
}
