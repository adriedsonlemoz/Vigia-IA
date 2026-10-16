import unittest
from pathlib import Path
from tool import check_ai_controls_258 as checks

ROOT = Path(__file__).resolve().parents[1]

class AiControls258Tests(unittest.TestCase):
    def test_contract(self):
        self.assertTrue(checks.check())

    def test_default_auto_and_choices(self):
        models = (ROOT/'lib/models/video_source_config.dart').read_text()
        for option in ['automatic(', 'yolo26s(', 'efficientDetLite2(',
                       'efficientDetLite0(', 'ssdMobileNetV1(']:
            self.assertIn(option, models)

    def test_manual_fallback_does_not_promote_heavier_model(self):
        assets = (ROOT/'lib/services/object_detection_assets.dart').read_text()
        self.assertIn('models.removeRange(0, index)', assets)
        self.assertNotIn('models.insert(0, models.removeAt(index))', assets)

    def test_nonmodal_diagnostic_preserves_controls(self):
        controls = (ROOT/'lib/screens/monitor_screen_ai_tools.dart').read_text()
        self.assertNotIn('barrierDismissible: false', controls)
        self.assertIn('_buildAiDiagnosticBanner', controls)
        self.assertIn('_sampleAiDiagnostic()', controls)
        self.assertIn('for (final seconds in const <int>[15, 30, 60, 120, 300, 600])', controls)
        self.assertIn('telemetry.createReport().deepTraceSamples', controls)

    def test_build212_regression(self):
        service = (ROOT/'lib/services/object_detection_service.dart').read_text()
        regression = (ROOT/'test/yolo_detection_decoder_test.dart').read_text()
        self.assertNotIn("import 'dart:typed_data';", service)
        self.assertIn('(320 + i).toDouble()', regression)

if __name__ == '__main__':
    unittest.main()
