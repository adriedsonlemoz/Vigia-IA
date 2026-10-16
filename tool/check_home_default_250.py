#!/usr/bin/env python3
"""Assegura que o modo normal abre Home sem destruir acesso ao mapa."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
app = (root / 'lib/app/app.dart').read_text()
launch = (root / 'lib/screens/launch_mode_screen.dart').read_text()
home = (root / 'lib/screens/home_screen_redesign.dart').read_text()
imports = (root / 'lib/screens/home_screen.dart').read_text()
assert 'AppLaunchMode.normal => _resumeMonitoring' in app
assert '? const HomeScreen(resumeMonitorOnLoad: true)' in app
assert ': const HomeScreen(),' in app
assert 'AppLaunchMode.bike => const MapWorkspaceShell()' in app
assert 'AppLaunchMode.normal => widget.startMonitorOnLoad' in launch
assert ': const HomeScreen(),' in launch
assert 'AppLaunchMode.bike => const MapWorkspaceShell()' in launch
assert 'onTap: () => _openScreen(const MapWorkspaceShell()),' in home
assert "import 'map_workspace_shell.dart';" in imports
assert "import 'mcrp_camera_screen.dart';" not in imports
assert "onTap: () => _openScreen(const McrpCameraScreen())," not in home
assert "title: 'Minha Câmera'" not in home
for expected in ('Ao vivo', 'Transmissão', 'Remoto', 'ESP32',
                 'Acessos rápidos', 'Monitoramento atual'):
    assert expected in home, expected
assert home.count('VigiaModeCard(') == 4
assert home.count('VigiaQuickAction(') == 1  # lista de 5 produz os cards
print('OK: Home, quatro modos, MCRP em Cameras, atalho do mapa, Bike e retomada.')
