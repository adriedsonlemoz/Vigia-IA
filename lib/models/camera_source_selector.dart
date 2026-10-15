import 'camera_endpoint.dart';
import 'video_source_config.dart';

/// Converte uma câmera cadastrada na fonte correta do Modo Ao vivo.
/// URLs HTTP /live/token de Minha Câmera jamais devem ser tratadas como RTSP.
VideoSourceConfig sourceForRegisteredCamera(
  CameraEndpoint camera,
  Duration analysisInterval,
) => switch (camera.type) {
  CameraEndpointType.local => VideoSourceConfig(
      type: VideoSourceType.localCamera,
      displayName: camera.name,
      cameraId: camera.id,
      analysisInterval: analysisInterval,
    ),
  CameraEndpointType.rtsp => VideoSourceConfig(
      type: VideoSourceType.rtsp,
      rtspUrl: camera.address,
      rtspSoftwareDecoding: camera.rtspSoftwareDecoding,
      displayName: camera.name,
      cameraId: camera.id,
      analysisInterval: analysisInterval,
    ),
  CameraEndpointType.remotePhone => VideoSourceConfig(
      type: VideoSourceType.remotePhone,
      remoteBaseUrl: camera.address,
      remoteAccessKey: camera.accessKey,
      displayName: camera.name,
      cameraId: camera.id,
      analysisInterval: analysisInterval,
    ),
  CameraEndpointType.esp32 => VideoSourceConfig(
      type: VideoSourceType.esp32,
      remoteBaseUrl: camera.address,
      remoteAccessKey: camera.accessKey,
      displayName: camera.name,
      cameraId: camera.id,
      analysisInterval: analysisInterval,
    ),
};
