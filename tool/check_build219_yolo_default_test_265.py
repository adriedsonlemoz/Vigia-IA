#!/usr/bin/env python3
"""Avoid APK 219: Flutter test expectations must match YOLO26s default."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
test = (root/'test/detector_model_preference_test.dart').read_text(encoding='utf-8')
model = (root/'lib/models/video_source_config.dart').read_text(encoding='utf-8')
settings = (root/'lib/services/app_settings_service.dart').read_text(encoding='utf-8')
assert 'this.detectorModel = DetectorModelPreference.yolo26s' in model
assert 'orElse: () => DetectorModelPreference.yolo26s' in settings
assert 'expect(settings.detectorModel, DetectorModelPreference.yolo26s);' in test
assert "expect(settings.detectorModel.label, 'YOLO26s');" in test
assert 'detectorModel: DetectorModelPreference.automatic' in test
assert 'expect(automatic.detectorModel, DetectorModelPreference.automatic);' in test
assert 'expect(settings.detectorModel, DetectorModelPreference.automatic)' not in test
print('Build 219: padrão YOLO26s e modo Automático preservados (Flutter test).')
