import 'package:flutter/material.dart';

import '../screens/access_guide_screen.dart';
import '../screens/home_screen.dart';
import '../services/appearance_settings_service.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final completed = await NativePlatformService.instance.onboardingCompleted();
    if (!mounted) return;
    setState(() => _onboardingCompleted = completed);
  }

  @override
  Widget build(BuildContext context) {
    final completed = _onboardingCompleted;
    if (completed == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (completed) return const HomeScreen();
    return const AccessGuideScreen();
  }
}
