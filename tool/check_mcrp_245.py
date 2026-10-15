#!/usr/bin/env python3
"""Contratos para integração IA+MCRP v245; não substitui flutter analyze/test."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
read=lambda n:(root/n).read_text(encoding='utf8')
screen=read('lib/screens/mcrp_camera_screen.dart')
client=read('lib/services/mcrp_client.dart')
source=read('lib/sources/minha_camera_mjpeg_source.dart')
native=read('lib/services/native_platform_service.dart')
android=read('android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt')
checks={
  'lint do CI 200': 'int.parse(p) < 0)) {' in client and ')) return false;' not in client,
  'somente fallback 404': "error.message == 'MCRP HTTP 404'" in client and 'McrpClient.supportsLegacyFallback(error)' in screen,
  'sem ignorar HTTP 403': "if (!McrpClient.supportsLegacyFallback(error)) {" in screen and "rethrow;" in screen,
  'status legado validado': "status['x-stream-codec'] == null" in screen,
  'mídia avançada só com MCRP': '_working || _legacy ? null : _loadMedia' in screen,
  'QR validado': 'McrpAddress.parse(raw)' in screen,
  'alternância IA': "SwitchListTile.adaptive(" in screen and "_analyze = value" in screen,
  'MJPEG reusa source': 'MinhaCameraMjpegSource(' in screen,
  'source reconexão': 'VideoSourceState.reconnecting' in screen and '_retry = Timer(' in source,
  'sem decoder MJPEG duplicado': 'pending.addAll(chunk)' not in screen,
  'uma fonte para IA e vídeo': 'emitFrames: widget.analysisEnabled' in screen and '_source.buildPreview()' in screen,
  'detector isolado no receptor': 'ObjectDetectionService()' in screen and 'await detector.detect(' in screen,
  'sobreposição objetiva': 'DetectionOverlay(' in screen and '_detections = detections' in screen,
  'desligar IA preserva vídeo': "if (widget.analysisEnabled) unawaited(_startAi(generation));" in screen,
  'limpeza stream': '_source.dispose()' in screen and 'detector.dispose()' in screen,
  'não processar H264 como MJPEG IA': "onChanged: codec == 'h264' ? null" in screen,
  'galeria usando arquivo stream': 'publishCameraMedia(' in native and 'file.inputStream().use' in android,
  'MediaStore imagens/vídeos': 'MediaStore.Images.Media.EXTERNAL_CONTENT_URI' in android and 'MediaStore.Video.Media.EXTERNAL_CONTENT_URI' in android,
  'galeria sem bytes na ponte': '"publishCameraMedia" -> {' in android and 'bytes' not in android.split('private fun publishCameraMedia(')[1].split('private fun saveBytesToDownloads')[0],
  'download mantém cópia privada': 'final file = await client.download(item, directory)' in screen and 'Pasta privada' in screen,
  'path sanitizado na camada Android': 'file.path.startsWith(root.path + File.separator)' in android,
  'verificador original mantido': (root/'tool/check_mcrp_244.py').is_file(),
}
for label,ok in checks.items():
 if not ok:raise SystemExit('MCRP 245: FALHA '+label)
print(f'MCRP 245: {len(checks)} contratos aprovados; flutter analyze/test pendentes.')
