import 'package:flutter/material.dart';

/// Base visual compartilhada do Vigia IA.
///
/// Mantém cores, raios, espaçamentos e componentes Material alinhados entre
/// Home, monitor, mapa e telas que serão migradas nas próximas etapas.
class VigiaColors {
  const VigiaColors._();

  static const Color backgroundDark = Color(0xFF06111E);
  static const Color surfaceDark = Color(0xFF0C1A29);
  static const Color surfaceRaisedDark = Color(0xFF102338);
  static const Color surfaceStrongDark = Color(0xFF152C44);
  static const Color cyan = Color(0xFF16B8FF);
  static const Color blue = Color(0xFF4C7DFF);
  static const Color green = Color(0xFF38D982);
  static const Color amber = Color(0xFFFFB84D);
  static const Color danger = Color(0xFFFF687A);
}

class VigiaRadii {
  const VigiaRadii._();

  static const double small = 12;
  static const double medium = 18;
  static const double large = 24;
  static const double pill = 999;
}

class VigiaSpacing {
  const VigiaSpacing._();

  static const double xs = 6;
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
}

class VigiaTheme {
  const VigiaTheme._();

  static ThemeData build({
    required Brightness brightness,
    required Color seed,
  }) {
    final dark = brightness == Brightness.dark;
    final baseScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final background = dark ? VigiaColors.backgroundDark : const Color(0xFFF3F7FB);
    final surface = dark ? VigiaColors.surfaceDark : Colors.white;
    final raised = dark ? VigiaColors.surfaceRaisedDark : const Color(0xFFEAF1F8);
    final strong = dark ? VigiaColors.surfaceStrongDark : const Color(0xFFDDE8F3);
    final primary = dark ? VigiaColors.cyan : const Color(0xFF006FA8);
    final secondary = dark ? VigiaColors.blue : const Color(0xFF315BC8);

    final scheme = baseScheme.copyWith(
      primary: primary,
      secondary: secondary,
      tertiary: VigiaColors.green,
      surface: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: raised,
      surfaceContainerHighest: strong,
      error: dark ? VigiaColors.danger : baseScheme.error,
    );

    final borderColor = scheme.outline.withValues(alpha: dark ? 0.18 : 0.26);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VigiaRadii.medium),
          side: BorderSide(color: borderColor),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VigiaRadii.medium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VigiaRadii.medium),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VigiaRadii.medium),
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minSize: const WidgetStatePropertyAll(Size(0, 46)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w800),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(VigiaRadii.medium),
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minSize: const WidgetStatePropertyAll(Size(0, 44)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: borderColor)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(VigiaRadii.medium),
            ),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: borderColor),
        backgroundColor: surface,
        selectedColor: primary.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VigiaRadii.pill),
        ),
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.16),
        selectedIconTheme: IconThemeData(color: primary, size: 23),
        unselectedIconTheme: IconThemeData(
          color: scheme.onSurfaceVariant,
          size: 22,
        ),
        selectedLabelTextStyle: TextStyle(
          color: primary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: surface,
        elevation: 0,
        indicatorColor: primary.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? primary
                : scheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? primary
                : scheme.onSurfaceVariant,
            size: states.contains(WidgetState.selected) ? 23 : 22,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? VigiaColors.surfaceStrongDark : scheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: dark ? Colors.white : scheme.onInverseSurface,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VigiaRadii.medium),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VigiaRadii.large),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(VigiaRadii.large),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: borderColor),
    );
  }
}
