import '../models/camera_endpoint.dart';
import 'minha_camera_live_url.dart';
import 'camera_registry_service.dart';
import 'mcrp_saved_cameras_store.dart';
import 'remote_camera_pairing_service.dart';

/// Migra cadastros da tela MCRP 1.0.248 para Câmeras uma única vez.
/// Não reconecta nem altera transmissor. Retira da lista antiga só após salvar.
Future<int> migrateMinhaCameraSavedEntries({
  CameraRegistryService? registry,
  McrpSavedCamerasStore? oldStore,
}) async {
  final cameras = registry ?? CameraRegistryService.instance;
  final legacy = oldStore ?? McrpSavedCamerasStore();
  await cameras.initialize();
  final oldEntries = await legacy.load();
  var transferred = 0;
  for (final saved in oldEntries) {
    final pairing = RemoteCameraPairingService.decode(saved.liveUrl);
    final newUrl = MinhaCameraLiveUrl.parse(pairing.address);
    final exists = cameras.items.any((item) {
      if (item.type != CameraEndpointType.remotePhone) return false;
      if (item.address == pairing.address) return true;
      final savedUrl = MinhaCameraLiveUrl.parse(item.address ?? '');
      return newUrl != null && savedUrl != null &&
          newUrl.host == savedUrl.host && newUrl.port == savedUrl.port;
    });
    if (!exists) {
      await cameras.save(CameraEndpoint(
        id: 'cam_${DateTime.now().microsecondsSinceEpoch}_$transferred',
        name: saved.name,
        type: CameraEndpointType.remotePhone,
        address: pairing.address,
        accessKey: pairing.accessKey,
      ));
      transferred++;
    }
    await legacy.remove(saved.liveUrl);
  }
  return transferred;
}

/// Limpa as chaves antigas desse transmissor quando o usuário remove a câmera.
/// Evita que uma versão antiga da URL reimporte um cadastro excluído.
Future<void> clearLegacyMinhaCameraForAddress(String? address, {
  McrpSavedCamerasStore? oldStore,
}) async {
  final selected = MinhaCameraLiveUrl.parse(address ?? '');
  if (selected == null) return;
  final legacy = oldStore ?? McrpSavedCamerasStore();
  for (final item in await legacy.load()) {
    final old = MinhaCameraLiveUrl.parse(item.liveUrl);
    if (old != null && selected.host == old.host &&
        selected.port == old.port) {
      await legacy.remove(item.liveUrl);
    }
  }
}
