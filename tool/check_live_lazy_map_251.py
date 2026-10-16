#!/usr/bin/env python3
"""Regras para Ao vivo local direto e localização sob demanda no Vigia IA 1.0.251."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def validate(read):
    home = read('lib/screens/home_screen.dart')
    ui = read('lib/screens/home_screen_redesign.dart')
    app = read('lib/app/app.dart')
    monitor = read('lib/screens/monitor_screen.dart')
    map_ui = read('lib/screens/monitor_screen_landscape_dashboard.dart')
    map_menu = read('lib/screens/monitor_screen_fullscreen.dart')
    map_panel = read('lib/screens/monitor_screen_portrait.dart')
    map_primary = read('lib/screens/monitor_screen_multicamera.dart')
    explorer = read('lib/screens/monitor_screen_map_explorer.dart')
    assert 'Future<void> _startLocalCamera() => _start(' in home
    assert "id: '__local__'" in home
    assert 'type: CameraEndpointType.local' in home
    assert 'unawaited(_startLocalCamera());' in ui
    for other in ('lib/screens/events_screen.dart', 'lib/screens/multi_camera_screen.dart'):
        assert 'HomeScreen(startMonitorOnLoad: true)' in read(other)
    assert 'onTap: () => unawaited(_startLocalCamera()),' in ui
    assert 'onTap: () => unawaited(_chooseCameraForLive()),' not in ui
    assert 'resumeMonitorOnLoad' in home
    assert 'widget.resumeMonitorOnLoad || resumeRequested' in home
    assert '? const HomeScreen(resumeMonitorOnLoad: true)' in app
    assert 'unawaited(_start());' in home
    startup = monitor.split('void initState() {', 1)[1].split('\n  void _updateFullscreenState', 1)[0]
    for forbidden in ('_initializeMiniMap(', '_initializeOfflineMiniMap(', '_routeExplorer.initialize(', '_mapRoute.acquireLocationConsumer('):
        assert forbidden not in startup, f'monitor iniciou recurso indevido: {forbidden}'
    assert 'bool _monitorMapActivated = false;' in monitor
    assert 'if (!mounted || !_monitorMapActivated) return;' in map_ui
    assert 'Future<void> _activateMonitorMap(' in map_ui
    assert 'unawaited(_initializeOfflineMiniMap());' in map_ui
    assert 'unawaited(_routeExplorer.initialize());' in map_ui
    assert '_mapRoute.releaseLocationConsumer(this);' in map_ui
    assert 'bool get _shouldShowMonitorMap => _monitorMapActivated &&' in map_ui
    assert 'await _activateMonitorMap();' in map_menu
    assert 'if (mode == MonitorMapVisibilityMode.hidden) _deactivateMonitorMap();' in map_menu
    assert '_setMonitorMapVisibilityQuick(selection.first)' in map_panel
    assert 'unawaited(_activateMonitorMap());' in map_primary
    assert explorer.count('_setMonitorMapVisibilityQuick(') >= 3
    assert 'releaseLocationIfIdle();' in read('lib/services/map_route_service.dart')
    assert 'recording: _tracking,' in read('lib/services/map_route_service.dart')
    assert 'navigating: navigating,' in read('lib/services/map_route_service.dart')
    assert 'onTap: () => _openScreen(const MapWorkspaceShell()),' in ui

if __name__ == '__main__':
    validate(lambda f: (ROOT / f).read_text(encoding='utf-8'))
    print('OK: Ao vivo local direto; GPS/MBTiles/Explorer somente sob demanda; retomada preservada.')
