import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/map_hud_presentation.dart';

MapHudPresentation hud({
  bool navigating = false,
  bool recording = false,
  double? speed,
  bool bikeMode = false,
  bool compact = false,
  bool? expanded,
  bool camera = false,
  bool radio = false,
  bool bike = false,
  bool alert = false,
}) => MapHudPresentationPolicy.resolve(
  hasNavigation: navigating,
  recording: recording,
  speedKmh: speed,
  pedalingModeSelected: bikeMode,
  compactScreen: compact,
  cameraOverlayVisible: camera,
  radioActive: radio,
  bikeConnected: bike,
  bikeAlert: alert,
  manuallyExpanded: expanded,
);

void main() {
  test('explorar inicia compacto, sem ativar periféricos ou esconder busca', () {
    final state = hud();
    expect(state.context, MapHudContext.exploring);
    expect(state.label, 'Explorar');
    expect(state.showTelemetry, isFalse);
    expect(state.showNearbyBanner, isFalse);
    expect(state.showCameraShortcut, isFalse);
    expect(state.showRadioShortcut, isFalse);
    expect(state.showBikeShortcut, isFalse);
    expect(state.recording, isFalse);
  });

  test('pedalar mostra instrumentos ao mover ou escolher modo Bike', () {
    expect(hud(speed: 7).context, MapHudContext.pedaling);
    expect(hud(speed: 7).showTelemetry, isTrue);
    expect(hud(bikeMode: true, speed: 0).context, MapHudContext.pedaling);
    expect(hud(speed: double.nan).context, MapHudContext.exploring);
    expect(hud(speed: 4.9).context, MapHudContext.exploring);
    // A tela envia null para origem Simulação; modo Bike continua explícito.
  });

  test('gravar e navegar simultaneamente mantém REC explícito', () {
    final state = hud(navigating: true, recording: true);
    expect(state.context, MapHudContext.navigating);
    expect(state.label, 'Navegar');
    expect(state.recording, isTrue);
    expect(state.showTelemetry, isFalse);
    expect(hud(recording: true).context, MapHudContext.recording);
    expect(hud(recording: true).showTelemetry, isTrue);
  });

  test('usuário pode expandir ou recolher em qualquer modo', () {
    expect(hud(expanded: true).showTelemetry, isTrue);
    expect(hud(speed: 12, expanded: false).showTelemetry, isFalse);
    expect(hud(navigating: true, expanded: true).showTelemetry, isTrue);
    expect(hud(expanded: true, compact: true).showNearbyBanner, isFalse);
    expect(hud(expanded: true, compact: true).showZoomControls, isFalse);
  });

  test('atalhos opcionais só aparecem em atividade ou alerta', () {
    final state = hud(camera: true, radio: true, alert: true);
    expect(state.showCameraShortcut, isTrue);
    expect(state.showRadioShortcut, isTrue);
    expect(state.showBikeShortcut, isTrue);
    expect(hud(bike: true).showBikeShortcut, isTrue);
    expect(hud().showBikeShortcut, isFalse);
  });
}
