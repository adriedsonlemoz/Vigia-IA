import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHECK = ROOT / 'tool' / 'check_build219_yolo_default_test_265.py'

class YoloDefaultFlutterRegressionTest(unittest.TestCase):
    def test_flutter_default_is_yolo26s(self):
        content = (ROOT / 'test' / 'detector_model_preference_test.dart').read_text(encoding='utf8')
        self.assertIn('expect(settings.detectorModel, DetectorModelPreference.yolo26s)', content)
        self.assertNotIn('expect(settings.detectorModel, DetectorModelPreference.automatic)', content)

    def test_automatic_option_remains_available(self):
        content = (ROOT / 'test' / 'detector_model_preference_test.dart').read_text(encoding='utf8')
        self.assertIn('expect(automatic.detectorModel, DetectorModelPreference.automatic)', content)

    def test_check_runs(self):
        completed = subprocess.run([sys.executable, str(CHECK)], cwd=ROOT, text=True, capture_output=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)

if __name__ == '__main__': unittest.main()
