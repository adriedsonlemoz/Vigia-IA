import '../core/video_source.dart';
import '../models/video_source_config.dart';
import '../services/minha_camera_live_url.dart';
import 'minha_camera_mjpeg_source.dart';
import 'remote_phone_camera_source.dart';

/// Compatibilidade binária/lógica das fontes: o protocolo é escolhido pelo
/// endereço validado do QR, sem alterar o enum histórico nem os outros apps.
VideoSource createRemotePhoneVideoSource(
  VideoSourceConfig config, {
  required Duration analysisInterval,
  bool emitFrames = true,
}) {
  if (MinhaCameraLiveUrl.isValid(config.remoteBaseUrl)) {
    return MinhaCameraMjpegSource(
      liveUrl: config.remoteBaseUrl!,
      analysisInterval: analysisInterval,
      emitFrames: emitFrames && config.analysisEnabled,
    );
  }
  return RemotePhoneCameraSource(
    baseUrl: config.remoteBaseUrl ?? '',
    accessKey: config.remoteAccessKey ?? '',
    analysisInterval: analysisInterval,
    emitFrames: emitFrames,
  );
}
