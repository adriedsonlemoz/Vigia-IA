#!/usr/bin/env python3
"""Contrato preventivo: QR salvo explicitamente em armazenamento privado local."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
store = (ROOT / 'lib/services/mcrp_saved_cameras_store.dart').read_text()
screen = (ROOT / 'lib/screens/mcrp_camera_screen.dart').read_text()
unit = (ROOT / 'test/mcrp_saved_cameras_store_test.dart').read_text()
widget = (ROOT / 'test/mcrp_saved_cameras_screen_test.dart').read_text()

checks = {
    'arquivo local privado': 'getApplicationSupportDirectory' in store,
    'dados persistidos em JSON': 'jsonEncode' in store and 'jsonDecode' in store,
    'validacao de URL segura': store.count('McrpAddress.parse(') >= 3,
    'cadastro somente sob comando explicito': 'Future<List<SavedMcrpCamera>> save(' in store and
        'await _savedStore.save(name: name, liveUrl: address)' in screen,
    'limite de memoria e cadastros': 'maximumFileBytes = 32768' in store and 'maximumCameras = 20' in store,
    'nao mostra token na lista': 'subtitle: Text(saved.networkAddress)' in screen and
        'return \'${uri.host}:${uri.port}\'' in store,
    'reconexao por toque': 'onTap: _working || _savingCamera ? null : () => _connectSavedCamera(saved)' in screen,
    'exclusao com confirmacao': 'Remover câmera salva?' in screen and
        'await _savedStore.remove(camera.liveUrl)' in screen,
    'armazenamento injetavel para testes': 'directoryProvider' in store and 'this.savedStore' in screen,
    'testes de persistencia': 'recupera após reiniciar' in unit,
    'testes de segurança': 'URLs públicas ou inválidas' in unit,
    'testes de widget': 'find.textContaining(token)' in widget,
}
for name, ok in checks.items():
    assert ok, f'FAIL: {name}'
    print('PASS:', name)
