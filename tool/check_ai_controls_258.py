#!/usr/bin/env python3
"""Contratos preventivos para seleção e teste rápido de IA no receptor."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def check():
    def read(path):
        return (ROOT / path).read_text(encoding='utf-8')
    models = read('lib/models/video_source_config.dart')
    store = read('lib/services/app_settings_service.dart')
    service = read('lib/services/object_detection_service.dart')
    assets = read('lib/services/object_detection_assets.dart')
    control = read('lib/controllers/monitor_controller_ai_support.dart')
    screen = read('lib/screens/monitor_screen_ai_tools.dart')
    top = read('lib/screens/monitor_screen_components.dart')
    portrait = read('lib/screens/monitor_screen_portrait.dart')
    assert 'this.detectorModel = DetectorModelPreference.automatic' in models
    assert 'DetectorModelPreference values' not in models
    assert "'detectorModel': settings.detectorModel.name" in store
    assert "orElse: () => DetectorModelPreference.automatic" in store
    assert 'ObjectDetectionService(preference: preference)' in control
    assert '_baseReady = false' in control and '_waitForProcessing()' in control
    assert 'await replacement.initialize()' in control
    assert 'models.removeRange(0, index)' in assets
    assert 'String get activeModel' in read('lib/services/object_detection_runtime.dart')
    assert 'this.onModelTap' in top and 'this.onDiagnosticTap' in top
    assert 'onModelTap: () => unawaited(_showAiModelPicker())' in portrait
    for word in ['15, 30, 60', 'startDeepTrace', 'stopDeepTrace',
                 'Teste de IA concluído', 'exportWithPicker', 'deepTraceSamples']:
        assert word in screen, word
    for transmitter in (ROOT/'lib').rglob('*transmitter*.dart'):
        assert 'ObjectDetectionService(' not in transmitter.read_text(encoding='utf-8'), transmitter
    assert "raw[0][i] = (320 + i).toDouble();" in read('test/yolo_detection_decoder_test.dart')
    assert "import 'dart:typed_data';" not in service
    return True

if __name__ == '__main__':
    check()
    print('IA 258: controles, automação, relatório, fallback, transmissor OK')
