import 'package:flutter/material.dart';

import 'map_view_settings_service.dart';

class MapAppearancePalette {
  const MapAppearancePalette({
    required this.routeColor,
    required this.routeColorHex,
    required this.routeCasingColor,
    required this.routeCasingColorHex,
    required this.currentPositionColor,
    required this.currentPositionColorHex,
    required this.destinationColor,
    required this.destinationColorHex,
    required this.buildingColorHex,
    required this.vectorStyleUrl,
    this.rasterColorMatrix,
  });

  final Color routeColor;
  final String routeColorHex;
  final Color routeCasingColor;
  final String routeCasingColorHex;
  final Color currentPositionColor;
  final String currentPositionColorHex;
  final Color destinationColor;
  final String destinationColorHex;
  final String buildingColorHex;
  final String vectorStyleUrl;
  final List<double>? rasterColorMatrix;
}

class MapAppearancePolicy {
  const MapAppearancePolicy._();

  static const String libertyStyleUrl =
      'https://tiles.openfreemap.org/styles/liberty';
  static const String darkStyleUrl =
      'https://tiles.openfreemap.org/styles/dark';
  static const String brightStyleUrl =
      'https://tiles.openfreemap.org/styles/bright';
  static const String fiordStyleUrl =
      'https://tiles.openfreemap.org/styles/fiord';

  // Inversão + rotação de matiz semelhante ao tratamento recomendado pelo
  // flutter_map para tiles raster em modo escuro. Não é uma camada preta.
  static const List<double> darkRasterMatrix = <double>[
    0.5740000009536743, -1.4299999475479126, -0.14399999380111694, 0, 255,
    -0.4259999990463257, -0.429999977350235, -0.14399999380111694, 0, 255,
    -0.4259999990463257, -1.4299999475479126, 0.8559999465942383, 0, 255,
    0, 0, 0, 1, 0,
  ];

  static const List<double> highContrastRasterMatrix = <double>[
    1.35, 0, 0, 0, -44.8,
    0, 1.35, 0, 0, -44.8,
    0, 0, 1.35, 0, -44.8,
    0, 0, 0, 1, 0,
  ];

  // Contraste moderado com reforço de verde/azul para conservar leitura de
  // vegetação, água e estradas em viagens sem alterar a geometria do mapa.
  static const List<double> bikeTravelRasterMatrix = <double>[
    1.06, -0.03, -0.03, 0, 1,
    -0.04, 1.12, -0.04, 0, -2,
    -0.03, -0.03, 1.10, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static MapAppearancePreset resolve({
    required MapAppearanceMode mode,
    required MapAppearancePreset manualPreset,
    required Brightness platformBrightness,
    required DateTime now,
  }) {
    return switch (mode) {
      MapAppearanceMode.manual => manualPreset,
      MapAppearanceMode.followSystem => platformBrightness == Brightness.dark
          ? MapAppearancePreset.dark
          : MapAppearancePreset.standard,
      MapAppearanceMode.dayNight => now.hour >= 19 || now.hour < 6
          ? MapAppearancePreset.dark
          : MapAppearancePreset.standard,
    };
  }

  static MapAppearancePalette palette(MapAppearancePreset preset) =>
      switch (preset) {
        MapAppearancePreset.standard => const MapAppearancePalette(
            routeColor: Color(0xFF006FF5),
            routeColorHex: '#006FF5',
            routeCasingColor: Color(0xFFFFFFFF),
            routeCasingColorHex: '#FFFFFF',
            currentPositionColor: Color(0xFF006FF5),
            currentPositionColorHex: '#006FF5',
            destinationColor: Color(0xFFE53956),
            destinationColorHex: '#E53956',
            buildingColorHex: '#C7CDD3',
            vectorStyleUrl: libertyStyleUrl,
          ),
        MapAppearancePreset.dark => const MapAppearancePalette(
            routeColor: Color(0xFF33D6FF),
            routeColorHex: '#33D6FF',
            routeCasingColor: Color(0xFF06131B),
            routeCasingColorHex: '#06131B',
            currentPositionColor: Color(0xFF33D6FF),
            currentPositionColorHex: '#33D6FF',
            destinationColor: Color(0xFFFF6B81),
            destinationColorHex: '#FF6B81',
            buildingColorHex: '#667784',
            vectorStyleUrl: darkStyleUrl,
            rasterColorMatrix: darkRasterMatrix,
          ),
        MapAppearancePreset.highContrast => const MapAppearancePalette(
            routeColor: Color(0xFFFFD600),
            routeColorHex: '#FFD600',
            routeCasingColor: Color(0xFF101010),
            routeCasingColorHex: '#101010',
            currentPositionColor: Color(0xFF00AEEF),
            currentPositionColorHex: '#00AEEF',
            destinationColor: Color(0xFFFF1744),
            destinationColorHex: '#FF1744',
            buildingColorHex: '#A0A0A0',
            vectorStyleUrl: brightStyleUrl,
            rasterColorMatrix: highContrastRasterMatrix,
          ),
        MapAppearancePreset.bikeTravel => const MapAppearancePalette(
            routeColor: Color(0xFF00B8A9),
            routeColorHex: '#00B8A9',
            routeCasingColor: Color(0xFF082A30),
            routeCasingColorHex: '#082A30',
            currentPositionColor: Color(0xFF00B8A9),
            currentPositionColorHex: '#00B8A9',
            destinationColor: Color(0xFFFF7043),
            destinationColorHex: '#FF7043',
            buildingColorHex: '#AAB8AD',
            vectorStyleUrl: fiordStyleUrl,
            rasterColorMatrix: bikeTravelRasterMatrix,
          ),
      };
}
