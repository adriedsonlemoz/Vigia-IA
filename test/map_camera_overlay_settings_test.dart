import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/map_camera_overlay_settings_service.dart';

void main() {
  group('MapCameraSlotLayout', () {
    test('serializa posição, tamanho e visibilidade', () {
      const layout = MapCameraSlotLayout(
        xFraction: 0.75,
        yFraction: 0.25,
        sizeScale: 1.25,
        minimized: true,
        hidden: false,
      );

      final restored = MapCameraSlotLayout.fromJson(layout.toJson());

      expect(restored.xFraction, 0.75);
      expect(restored.yFraction, 0.25);
      expect(restored.sizeScale, 1.25);
      expect(restored.minimized, isTrue);
      expect(restored.hidden, isFalse);
    });

    test('limita valores corrompidos ao intervalo seguro', () {
      final restored = MapCameraSlotLayout.fromJson(<String, dynamic>{
        'xFraction': 9,
        'yFraction': -2,
        'sizeScale': 4,
      });

      expect(restored.xFraction, 1);
      expect(restored.yFraction, 0);
      expect(restored.sizeScale, 1.35);
    });
  });
}
