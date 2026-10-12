/// Política sem efeitos colaterais para o HUD. Gravar e navegar são estados
/// independentes: navegar não cancela uma gravação em andamento.
enum MapHudContext { exploring, pedaling, navigating, recording }

class MapHudPresentation {
  const MapHudPresentation({
    required this.context,
    required this.recording,
    required this.showTelemetry,
    required this.showNearbyBanner,
    required this.showCameraShortcut,
    required this.showRadioShortcut,
    required this.showBikeShortcut,
    required this.showZoomControls,
  });

  final MapHudContext context;
  final bool recording;
  final bool showTelemetry;
  final bool showNearbyBanner;
  final bool showCameraShortcut;
  final bool showRadioShortcut;
  final bool showBikeShortcut;
  final bool showZoomControls;

  String get label => switch (context) {
    MapHudContext.exploring => 'Explorar',
    MapHudContext.pedaling => 'Pedalar',
    MapHudContext.navigating => 'Navegar',
    MapHudContext.recording => 'Gravar',
  };
}

class MapHudPresentationPolicy {
  const MapHudPresentationPolicy._();

  static MapHudPresentation resolve({
    required bool hasNavigation,
    required bool recording,
    required double? speedKmh,
    bool pedalingModeSelected = false,
    required bool compactScreen,
    required bool cameraOverlayVisible,
    required bool radioActive,
    required bool bikeConnected,
    required bool bikeAlert,
    bool? manuallyExpanded,
  }) {
    // O contexto visual de navegação tem precedência, mas não substitui REC.
    final context = hasNavigation
        ? MapHudContext.navigating
        : recording
            ? MapHudContext.recording
            : pedalingModeSelected ||
                    (speedKmh != null && speedKmh.isFinite && speedKmh >= 5)
                ? MapHudContext.pedaling
                : MapHudContext.exploring;
    final defaultExpanded = context == MapHudContext.pedaling ||
        context == MapHudContext.recording;
    final expanded = manuallyExpanded ?? defaultExpanded;

    return MapHudPresentation(
      context: context,
      recording: recording,
      showTelemetry: expanded,
      // A busca de POIs segue acessível pelo botão dedicado e pelo menu.
      showNearbyBanner: expanded && !compactScreen,
      // Não iniciar câmeras, sensores ou rádio apenas por mostrar o HUD.
      showCameraShortcut: cameraOverlayVisible,
      showRadioShortcut: radioActive,
      showBikeShortcut: bikeConnected || bikeAlert,
      // Gestos de zoom permanecem disponíveis ao recolher controles.
      showZoomControls: expanded && !compactScreen,
    );
  }
}
