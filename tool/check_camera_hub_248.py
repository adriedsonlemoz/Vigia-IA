#!/usr/bin/env python3
"""Guarda o fluxo Câmeras → Ao vivo após integração MJPEG/MCRP."""
from pathlib import Path
p=Path(__file__).resolve().parents[1]
read=lambda name: (p/name).read_text()
home=read('lib/screens/home_screen.dart')
home_ui=read('lib/screens/home_screen_redesign.dart')
cameras=read('lib/screens/multi_camera_screen.dart')
card=read('lib/screens/multi_camera_screen_components.dart')
monitor=read('lib/screens/monitor_screen.dart')
selector=read('lib/models/camera_source_selector.dart')
migration=read('lib/services/minha_camera_registry_migration.dart')
checks={
 'home sem módulo duplicado': "title: 'Minha Câmera'" not in home_ui,
 'home preserva modos e atalhos': all(s in home_ui for s in ("title: 'Modos'", "label: 'Câmeras'", "title: 'Ao vivo'")),
 'ao vivo solicita escolha': 'Future<void> _chooseCameraForLive()' in home and 'onTap: () => unawaited(_chooseCameraForLive())' in home_ui,
 'não obriga URL RTSP antiga': 'if (camera == null) {\n          await _chooseCameraForLive();' in home,
 'fonte remota não é RTSP': 'CameraEndpointType.remotePhone => VideoSourceConfig(' in selector and 'type: VideoSourceType.remotePhone' in selector,
 'ao vivo salva fonte selecionada': 'sourceForRegisteredCamera(camera, current.source.analysisInterval)' in home,
 'monitor pode voltar à Home': "tooltip: 'Voltar ao início'" in monitor and 'const HomeScreen()' in monitor,
 'câmeras admite QR e URL MJPEG': 'RemoteCameraPairingService.decode(raw)' in cameras and 'MinhaCameraLiveUrl.parse(value)' in cameras,
 'Câmeras recebe cadastros da 247': 'migrateMinhaCameraSavedEntries(registry: _registry)' in cameras and 'await legacy.remove(saved.liveUrl)' in migration,
 'migracao protege duplicatas': 'item.address == pairing.address' in migration,
 'limpeza de registro legado ao remover': 'await _clearLegacyOnDelete(camera)' in cameras and 'clearLegacyMinhaCameraForAddress' in migration,
 'QR rotativo atualiza cadastro existente': 'minha.host == saved.host && minha.port == saved.port' in read('lib/screens/multi_camera_screen_saved_support.dart'),
 'esconder token no diálogo QR': "MinhaCameraLiveUrl.parse(endpoint.address ?? '')?.host" in cameras,
 'câmeras editam e apagam': '_editCamera(camera)' in cameras and '_deleteCamera(camera)' in cameras,
 'MCRP continua via Câmeras': 'onMcrpControls:' in cameras and "child: Text('Controles e arquivos')" in card,
 'seleção Câmeras persiste último Ao vivo': 'await _settings.saveProfile(PersistedMonitorProfile(' in read('lib/screens/multi_camera_screen_monitoring.dart'),
 'QR vigente ainda validado local': 'MinhaCameraLiveUrl.parse(raw)' in read('lib/services/remote_camera_pairing_service.dart'),
 'fonte MJPEG continua habilitada': 'MinhaCameraMjpegSource' in read('lib/sources/remote_phone_source_factory.dart'),
}
for label,passed in checks.items():
 if not passed: raise AssertionError(label)
 print('PASS:',label)
print(f'Cameras / Ao vivo: {len(checks)} contratos aprovados.')
