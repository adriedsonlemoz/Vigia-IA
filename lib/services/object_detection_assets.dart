part of 'object_detection_service.dart';

Future<List<Map<String, Object>>> _loadDetectorAssets() async {
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
  return models;
}
