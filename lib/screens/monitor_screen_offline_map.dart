part of 'monitor_screen.dart';

extension _MonitorScreenOfflineMapSupport on _MonitorScreenState {
  Future<void> _initializeOfflineMiniMap() async {
    await _offlineMaps.initialize();
    if (!mounted) return;
    _syncMiniOfflineProvider();
  }

  void _onOfflineMapsChanged() {
    if (!mounted) return;
    _syncMiniOfflineProvider();
  }

  void _syncMiniOfflineProvider() {
    final active = _offlineMaps.activePackage;
    if (_miniOfflinePackageId == active?.id) {
      setState(() {});
      return;
    }
    _miniOfflineTileProvider?.dispose();
    _miniOfflineTileProvider = null;
    _miniOfflinePackageId = active?.id;
    _miniOfflineMinZoom = 0;
    _miniOfflineMaxZoom = 19;
    if (active != null) {
      try {
        final provider = MbTilesTileProvider.fromPath(path: active.path);
        final metadata = provider.mbtiles.getMetadata();
        final minZoom = (metadata.minZoom ?? 0).floor().clamp(0, 22);
        final maxZoom = (metadata.maxZoom ?? 19).ceil().clamp(minZoom, 22);
        _miniOfflineMinZoom = minZoom.toInt();
        _miniOfflineMaxZoom = maxZoom.toInt();
        _miniOfflineTileProvider = provider;
      } catch (_) {
        _miniOfflineTileProvider = null;
      }
    }
    setState(() {});
  }
}
