import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/video_source_config.dart';

void main() {
  test('modelo de IA padrao e automatico', () {
    const settings = MonitorSettings();
    expect(settings.detectorModel, DetectorModelPreference.automatic);
    expect(settings.detectorModel.label, 'Automático');
  });

  test('preferencia manual nao muda outros ajustes da IA', () {
    const settings = MonitorSettings(aiEnabled: false);
    final manual = settings.copyWith(
      detectorModel: DetectorModelPreference.yolo26s,
    );
    expect(manual.detectorModel, DetectorModelPreference.yolo26s);
    expect(manual.aiEnabled, isFalse);
    expect(manual.trackingEnabled, settings.trackingEnabled);
    expect(manual.copyWith(detectorModel: DetectorModelPreference.automatic)
        .detectorModel, DetectorModelPreference.automatic);
  });
}
