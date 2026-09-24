import 'package:flutter/material.dart';

import '../core/vigia_design.dart';
import '../screens/access_guide_screen.dart';
import '../screens/bike_mode_screen.dart';
import '../screens/camera_mode_screen.dart';
import '../screens/home_screen.dart';
import '../screens/launch_mode_screen.dart';
import '../screens/monitor_connect_screen.dart';
import '../services/appearance_settings_service.dart';
import '../services/app_launch_mode_service.dart';
import '../services/native_platform_service.dart';

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
  bool? _onboardingCompleted;
  AppLaunchMode? _launchMode;
  bool _launchModeLoaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final completed = await NativePlatformService.instance.onboardingCompleted();
    final launchMode = completed
        ? await AppLaunchModeService.instance.initialize()
        : null;
    if (!mounted) return;
    setState(() {
      _onboardingCompleted = completed;
      _launchMode = launchMode;
      _launchModeLoaded = true;
    });
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
        AppLaunchMode.bike => const BikeModeScreen(),
        AppLaunchMode.transmission => const CameraModeScreen(),
        null => const LaunchModeScreen(),
      };
      return _PermissionReminderHost(child: destination);
    }
    return const AccessGuideScreen();
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPermissions());
  }

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
  Widget build(BuildContext context) => widget.child;
}
