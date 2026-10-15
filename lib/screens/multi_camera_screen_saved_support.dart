part of 'multi_camera_screen.dart';

/// Reutiliza o cadastro quando o Minha Câmera atualiza seu token via QR.
/// Host+porta são únicos para o mesmo transmissor na rede local.
CameraEndpoint? _findRemotePhoneByAddress(
  List<CameraEndpoint> cameras,
  String address,
) {
  final minha = MinhaCameraLiveUrl.parse(address);
  for (final item in cameras) {
    if (item.type != CameraEndpointType.remotePhone) continue;
    if (item.address == address) return item;
    final saved = MinhaCameraLiveUrl.parse(item.address ?? '');
    if (minha != null && saved != null &&
        minha.host == saved.host && minha.port == saved.port) {
      return item;
    }
  }
  return null;
}

Future<void> _clearLegacyOnDelete(CameraEndpoint camera) async {
  try {
    await clearLegacyMinhaCameraForAddress(camera.address);
  } catch (_) {
    // Uma cópia antiga corrompida não impede excluir o cadastro central.
  }
}
