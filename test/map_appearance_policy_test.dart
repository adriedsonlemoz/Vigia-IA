import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/map_appearance_policy.dart';
import 'package:vigiaia/services/map_view_settings_service.dart';

void main() {
  test('oferece os quatro temas visuais previstos', () {
    expect(
      MapAppearancePreset.values.map((value) => value.name),
      containsAll(<String>['standard', 'dark', 'highContrast', 'bikeTravel']),
    );
  });

  test('seguir sistema alterna somente entre padrao e escuro', () {
    expect(
      MapAppearancePolicy.resolve(
        mode: MapAppearanceMode.followSystem,
        manualPreset: MapAppearancePreset.bikeTravel,
        platformBrightness: Brightness.light,
        now: DateTime(2026, 9, 26, 12),
      ),
      MapAppearancePreset.standard,
    );
    expect(
      MapAppearancePolicy.resolve(
        mode: MapAppearanceMode.followSystem,
        manualPreset: MapAppearancePreset.bikeTravel,
        platformBrightness: Brightness.dark,
        now: DateTime(2026, 9, 26, 12),
      ),
      MapAppearancePreset.dark,
    );
  });

  test('dia noite usa relogio local sem depender de rede', () {
    expect(
      MapAppearancePolicy.resolve(
        mode: MapAppearanceMode.dayNight,
        manualPreset: MapAppearancePreset.highContrast,
        platformBrightness: Brightness.light,
        now: DateTime(2026, 9, 26, 14),
      ),
      MapAppearancePreset.standard,
    );
    expect(
      MapAppearancePolicy.resolve(
        mode: MapAppearanceMode.dayNight,
        manualPreset: MapAppearancePreset.standard,
        platformBrightness: Brightness.light,
        now: DateTime(2026, 9, 26, 22),
      ),
      MapAppearancePreset.dark,
    );
  });

  test('rota mantem cor e contorno dedicados em todos os temas', () {
    for (final preset in MapAppearancePreset.values) {
      final palette = MapAppearancePolicy.palette(preset);
      expect(palette.routeColorHex, isNotEmpty);
      expect(palette.routeCasingColorHex, isNotEmpty);
      expect(palette.routeColorHex, isNot(palette.routeCasingColorHex));
      expect(palette.currentPositionColorHex, isNotEmpty);
      expect(palette.vectorStyleUrl, startsWith('https://'));
    }
  });
}
