import 'package:flutter/material.dart';

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

  ThemeData _theme({required Brightness brightness, required Color seed}) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final background = dark ? const Color(0xFF07111F) : const Color(0xFFF5F7FA);
    final surface = dark ? const Color(0xFF0D1B2A) : Colors.white;
    final surfaceHigh = dark ? const Color(0xFF13263A) : const Color(0xFFE9EEF5);
    final effectiveScheme = scheme.copyWith(
      surface: surface,
      surfaceContainerHighest: surfaceHigh,
      error: dark ? const Color(0xFFFF6B78) : scheme.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: effectiveScheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: effectiveScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: effectiveScheme.outline.withValues(alpha: dark ? 0.18 : 0.30),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: effectiveScheme.primary, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF1B3147) : effectiveScheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: dark ? Colors.white : effectiveScheme.onInverseSurface,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: effectiveScheme.primary.withValues(alpha: 0.14),
        selectedIconTheme: IconThemeData(color: effectiveScheme.primary, size: 23),
        unselectedIconTheme: IconThemeData(
          color: effectiveScheme.onSurfaceVariant,
          size: 22,
        ),
        selectedLabelTextStyle: TextStyle(
          color: effectiveScheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: effectiveScheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: surface,
        indicatorColor: effectiveScheme.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? effectiveScheme.primary
                : effectiveScheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? effectiveScheme.primary
                : effectiveScheme.onSurfaceVariant,
            size: 22,
          );
        }),
      ),
      dividerTheme: DividerThemeData(
        color: effectiveScheme.outline.withValues(alpha: 0.16),
      ),
    );
  }

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
