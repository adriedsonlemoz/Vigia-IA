part of 'object_detection_service.dart';

Future<List<Map<String, Object>>> _loadDetectorAssets(
  DetectorModelPreference preference,
) async {
  final models = <Map<String, Object>>[];
  for (final entry in const <(String, String)>[
      ('YOLO26s', ObjectDetectionService._yoloModelAsset),
      ('EfficientDet-Lite2', ObjectDetectionService._lite2ModelAsset),
      ('EfficientDet-Lite0', ObjectDetectionService._primaryModelAsset),
      ('SSD MobileNet V1', ObjectDetectionService._fallbackModelAsset),
  ]) {
    ByteData modelData;
    try {
      modelData = await rootBundle.load(entry.$2);
    } catch (_) {
      // Modelo opcional ausente: os demais continuam disponíveis.
      continue;
    }
    if (modelData.lengthInBytes < 1024 * 1024) continue;
    final bytes = modelData.buffer.asUint8List(
      modelData.offsetInBytes,
      modelData.lengthInBytes,
    );
    models.add(<String, Object>{
      'name': entry.$1,
      'bytes': TransferableTypedData.fromList([bytes]),
    });
  }
  if (preference != DetectorModelPreference.automatic) {
    final requested = switch (preference) {
      DetectorModelPreference.yolo26s => 'YOLO26s',
      DetectorModelPreference.efficientDetLite2 => 'EfficientDet-Lite2',
      DetectorModelPreference.efficientDetLite0 => 'EfficientDet-Lite0',
      DetectorModelPreference.ssdMobileNetV1 => 'SSD MobileNet V1',
      DetectorModelPreference.automatic => '',
    };
    final index = models.indexWhere((model) => model['name'] == requested);
    if (index >= 0) {
      // Manter a ordem de custo: após uma escolha manual, somente versões
      // mais leves podem servir de fallback (nunca promover a carga).
      models.removeRange(0, index);
    }
    // Se o escolhido não estiver empacotado, mantém alternativas e informa
    // o modelo realmente carregado nos diagnósticos.
  }
  return models;
}
