import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/core/adaptive_camera_layout.dart';

void main() {
  test('uma câmera sempre usa toda a área', () {
    expect(
      adaptiveCameraLayoutFor(
        cameraCount: 1,
        landscape: true,
        availableWidth: 1200,
      ),
      AdaptiveCameraLayout.single,
    );
  });

  test('duas câmeras ficam empilhadas no celular vertical', () {
    expect(
      adaptiveCameraLayoutFor(
        cameraCount: 2,
        landscape: false,
        availableWidth: 412,
      ),
      AdaptiveCameraLayout.stacked,
    );
  });

  test('duas câmeras ficam lado a lado no modo horizontal', () {
    expect(
      adaptiveCameraLayoutFor(
        cameraCount: 2,
        landscape: true,
        availableWidth: 720,
      ),
      AdaptiveCameraLayout.sideBySide,
    );
  });
}
