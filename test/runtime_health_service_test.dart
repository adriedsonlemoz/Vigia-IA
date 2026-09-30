import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/runtime_health_service.dart';

void main() {
  test('frames recentes expiram quando ficam congelados', () {
    final runtime = RuntimeHealthService.instance;
    final now = DateTime(2026, 9, 17, 22, 0, 10);
    runtime.updateFrame(now.subtract(const Duration(seconds: 3)), 5);
    expect(runtime.framesAreFresh(now), isTrue);

    runtime.updateFrame(now.subtract(const Duration(seconds: 9)), 5);
    expect(runtime.framesAreFresh(now), isFalse);
    runtime.stopMonitoring();
  });

  test('LAN so fica recente enquanto existe JPEG novo', () {
    final runtime = RuntimeHealthService.instance;
    final now = DateTime(2026, 9, 18, 8, 0, 10);
    runtime.updateLan(
      active: true,
      clients: 1,
      lastFrameAt: now.subtract(const Duration(seconds: 4)),
    );
    expect(runtime.lanFramesAreFresh(now), isTrue);

    runtime.updateLan(
      active: true,
      clients: 1,
      lastFrameAt: now.subtract(const Duration(seconds: 7)),
    );
    expect(runtime.lanFramesAreFresh(now), isFalse);
    runtime.stopMonitoring();
  });
}
