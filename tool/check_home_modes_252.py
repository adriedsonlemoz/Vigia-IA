#!/usr/bin/env python3
"""Quatro modos na Home sem perder controle MCRP na central Câmeras."""
from pathlib import Path
r=Path(__file__).resolve().parents[1]
read=lambda n:(r/n).read_text(encoding='utf-8')
home=read('lib/screens/home_screen_redesign.dart')
master=read('lib/screens/home_screen.dart')
hub=read('lib/screens/multi_camera_screen.dart')
card=read('lib/screens/multi_camera_screen_components.dart')
assert home.count('VigiaModeCard(')==4
for title in ('Ao vivo','Transmissão','Remoto','ESP32'):
 assert f"title: '{title}'" in home,title
assert "title: 'Minha Câmera'" not in home
assert 'McrpCameraScreen' not in home
assert "import 'mcrp_camera_screen.dart';" not in master
assert "onTap: () => unawaited(_startLocalCamera())" in home
assert "onTap: () => _openScreen(const MapWorkspaceShell())," in home
assert 'McrpCameraScreen(' in hub and 'onMcrpControls:' in hub
assert "child: Text('Controles e arquivos')" in card
assert 'MinhaCameraLiveUrl.isValid(camera.address)' in hub
assert 'migrateMinhaCameraSavedEntries(registry: _registry)' in hub
assert 'await _registry.save(endpoint)' in hub
assert 'McrpClient' in read('lib/screens/mcrp_camera_screen.dart')
print('Home 252: quatro modos, MCRP e câmeras cadastradas preservadas.')
