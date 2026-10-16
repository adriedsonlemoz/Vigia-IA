"""Valida YOLO26s como padrão e build fail-closed em caso de exportação ausente."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def read(path): return (ROOT/path).read_text(encoding='utf-8')

class YoloDefault263(unittest.TestCase):
    def test_default_model_is_yolo26s(self):
        self.assertIn('this.detectorModel = DetectorModelPreference.yolo26s', read('lib/models/video_source_config.dart'))
        self.assertIn('orElse: () => DetectorModelPreference.yolo26s', read('lib/services/app_settings_service.dart'))

    def test_auto_still_prioritizes_yolo(self):
        assets=read('lib/services/object_detection_assets.dart')
        self.assertLess(assets.index("('YOLO26s',"), assets.index("('EfficientDet-Lite2',"))
        self.assertIn('if (preference != DetectorModelPreference.automatic)',assets)
        self.assertIn('models.removeRange(0, index)',assets)

    def test_ui_explains_actual_preference(self):
        screen=read('lib/screens/monitor_screen_ai_tools.dart')
        self.assertIn('Padrão do Vigia IA',screen)
        self.assertIn('Tenta YOLO26s primeiro',screen)
        self.assertIn('_controller.activeDetectorModel',screen)

    def test_build_requires_real_yolo(self):
        ci=read('.github/workflows/android-apk.yml')
        self.assertIn('timeout 900 bash ./tool/export_yolo26s.sh',ci)
        self.assertIn('python3 tool/export_yolo26s.py',ci)
        self.assertIn('APK sem YOLO26s real',ci)
        self.assertIn('3_000_000',ci)
        self.assertIn('actual_sha != expected_sha',ci)
        self.assertNotIn('if timeout 600 bash ./tool/export_yolo26s.sh',ci)
        self.assertIn('flutter analyze --fatal-infos --fatal-warnings',ci)

    def test_modern_official_export_and_validation(self):
        export=read('tool/export_yolo26s.py')
        self.assertIn("model.export(format='litert', imgsz=640)",export)
        self.assertIn('validate(source)',export)
        self.assertIn('YOLO26s validado:',export)
        self.assertIn('3_000_000',export)

    def test_only_receiver_performs_ai(self):
        for transmitter in (ROOT/'lib').rglob('*transmitter*.dart'):
            self.assertNotIn('ObjectDetectionService(',transmitter.read_text(encoding='utf-8'))
        self.assertIn('String get activeModel',read('lib/services/object_detection_runtime.dart'))

if __name__ == '__main__': unittest.main()
