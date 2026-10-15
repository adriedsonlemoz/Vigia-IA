import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_build195_widget_text_240 import audit, check

class Build195WidgetTextRegression(unittest.TestCase):
    def setUp(self):
        root = Path(__file__).resolve().parents[1]
        self.files = [
            (root / 'lib/widgets/map_telemetry_strip.dart').read_text(encoding='utf8'),
            (root / 'lib/widgets/map_status_indicators.dart').read_text(encoding='utf8'),
            (root / 'test/map_telemetry_strip_test.dart').read_text(encoding='utf8'),
            (root / 'test/map_status_indicators_test.dart').read_text(encoding='utf8'),
        ]

    def test_corrected_expectations(self):
        self.assertEqual(check(), [])

    def test_rejects_old_separate_number_expectation(self):
        x = self.files[:]
        x[2] = x[2].replace("find.text('19.8 km/h')", "find.text('19.8')", 1)
        self.assertTrue(audit(*x))

    def test_rejects_old_unrendered_heading_word(self):
        x = self.files[:]
        x[3] = x[3].replace("find.text('GPS · 92°')", "find.text('GPS · rumo 92°')")
        self.assertTrue(audit(*x))

    def test_rejects_loss_of_rich_text_unit(self):
        x = self.files[:]
        x[0] = x[0].replace("const TextSpan(text: ' ')", "const TextSpan(text: '')")
        self.assertTrue(audit(*x))

if __name__ == '__main__':
    unittest.main()
