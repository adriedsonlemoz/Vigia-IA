import 'dart:async';

import 'package:flutter/material.dart';

import '../core/vigia_design.dart';
import '../screens/access_guide_screen.dart';
import '../screens/camera_mode_screen.dart';
import '../screens/home_screen.dart';
import '../screens/launch_mode_screen.dart';
import '../screens/monitor_connect_screen.dart';
import '../services/appearance_settings_service.dart';
import '../services/bike_pressure_safety_service.dart';
import '../services/app_launch_mode_service.dart';
import '../services/esp32_telemetry_service.dart';
import '../services/native_platform_service.dart';
import '../services/startup_guard.dart';
import '../widgets/update_news_host.dart';

class VigiaIaApp extends StatelessWidget {
  const VigiaIaApp({super.key});

  ThemeData _theme({required Brightness brightness, required Color seed}) =>
      VigiaTheme.build(brightness: brightness, seed: seed);

  @override
  Widget build(BuildContext context) {
    final appearance = AppearanceSettingsService.instance;
    return AnimatedBuilder(
      animation: appearance,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Vigia IA',
        themeMode: appearance.themeMode,
        theme: _theme(brightness: Brightness.light, seed: appearance.seedColor),
        darkTheme: _theme(brightness: Brightness.dark, seed: appearance.seedColor),
        home: const _StartupGate(),
      ),
    );
  }
}


class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  static const Duration _requiredStartupTimeout = Duration(seconds: 4);
  static const Duration _optionalStartupTimeout = Duration(seconds: 8);

  final StartupGuard _startupGuard = const StartupGuard();
  bool? _onboardingCompleted;
  AppLaunchMode? _launchMode;
  bool _launchModeLoaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final completed =
        await _startupGuard.run<bool>(
          NativePlatformService.instance.onboardingCompleted,
          timeout: _requiredStartupTimeout,
          onError: (error, stackTrace) => _traceStartupIssue(
            'onboarding',
            error,
            stackTrace,
          ),
        ) ??
        false;
    final launchMode = completed
        ? await _startupGuard.run<AppLaunchMode?>(
            AppLaunchModeService.instance.initialize,
            timeout: _requiredStartupTimeout,
            onError: (error, stackTrace) => _traceStartupIssue(
              'modo inicial',
              error,
              stackTrace,
            ),
          )
        : null;

    if (!mounted) return;
    setState(() {
      _onboardingCompleted = completed;
      _launchMode = launchMode;
      _launchModeLoaded = true;
    });

    if (completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_initializeOptionalServices());
      });
    }
  }

  Future<void> _initializeOptionalServices() async {
    await Future.wait<void>(<Future<void>>[
      _initializeOptionalService(
        'ESP32',
        Esp32TelemetryService.instance.initialize,
      ),
      _initializeOptionalService(
        'segurança Bike',
        BikePressureSafetyService.instance.initialize,
      ),
    ]);
  }

  Future<void> _initializeOptionalService(
    String name,
    Future<void> Function() initialize,
  ) =>
      _startupGuard.runOptional(
        initialize,
        timeout: _optionalStartupTimeout,
        onError: (error, stackTrace) =>
            _traceStartupIssue(name, error, stackTrace),
      );

  void _traceStartupIssue(
    String stage,
    Object error,
    StackTrace stackTrace,
  ) {
    debugPrint('Vigia IA startup [$stage]: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  @override
  Widget build(BuildContext context) {
    final completed = _onboardingCompleted;
    if (completed == null || !_launchModeLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (completed) {
      final launchMode = _launchMode;
      final destination = switch (launchMode) {
        AppLaunchMode.normal => const HomeScreen(),
        AppLaunchMode.monitor => const MonitorConnectScreen(),
        AppLaunchMode.bike => const HomeScreen(),
        AppLaunchMode.transmission => const CameraModeScreen(),
        null => const LaunchModeScreen(),
      };
      return _PermissionReminderHost(child: destination);
    }
    return const UpdateNewsHost(child: AccessGuideScreen());
  }
}

/// Orienta novamente sobre permissões obrigatórias removidas após o onboarding,
/// sem reiniciar a seleção de modo nem apagar a preferência do usuário.
class _PermissionReminderHost extends StatefulWidget {
  const _PermissionReminderHost({required this.child});

  final Widget child;

  @override
  State<_PermissionReminderHost> createState() => _PermissionReminderHostState();
}

class _PermissionReminderHostState extends State<_PermissionReminderHost> {
  bool _checked = false;

  Future<void> _checkPermissions() async {
    if (_checked || !mounted) return;
    _checked = true;
    final native = NativePlatformService.instance;
    final results = await Future.wait<Object>([
      native.cameraPermissionStatus(),
      native.localNetworkPermissionStatus(),
    ]);
    if (!mounted) return;
    final camera = results[0] as CameraPermissionStatus;
    final network = results[1] as LocalNetworkPermissionStatus;
    final missing = <String>[
      if (!camera.granted) 'câmera',
      if (network.required && !network.granted) 'rede local/dispositivos próximos',
    ];
    if (missing.isEmpty) return;

    final review = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Permissão pendente'),
        content: Text(
          'O acesso a ${missing.join(' e ')} está desativado. Algumas funções podem não abrir até você revisar essa permissão.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Agora não'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Revisar permissões'),
          ),
        ],
      ),
    );
    if (review != true || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AccessGuideScreen(manualReview: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => UpdateNewsHost(
        onHandled: _checkPermissions,
        child: widget.child,
      );
}
