import 'package:flutter/services.dart';

/// Centraliza a política de orientação do Vigia IA.
///
/// Regra do aplicativo:
/// - telas normais: somente retrato;
/// - modo Transmissão: acompanha livremente a posição física do aparelho.
class AppOrientationService {
  const AppOrientationService._();

  static const List<DeviceOrientation> portraitOnly = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ];

  static const List<DeviceOrientation> transmissionAuto = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  static Future<void> lockPortrait() =>
      SystemChrome.setPreferredOrientations(portraitOnly);

  static Future<void> allowTransmissionRotation() =>
      SystemChrome.setPreferredOrientations(transmissionAuto);
}
