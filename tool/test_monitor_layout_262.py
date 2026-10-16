import unittest
from pathlib import Path
from tool.check_monitor_layout_262 import check_source, ROOT

class MonitorLayout262Test(unittest.TestCase):
    def test_contract(self):
        self.assertEqual(check_source(), [])
    def test_floating_regression(self):
        src=self._content();src['lib/screens/monitor_screen_multicamera.dart']+='\nWidget _buildPortraitPictureInPictureStage';
        self.assertIn('Floating video miniatura is still used',check_source(src))
    def test_confidence_regression(self):
        src=self._content();src['lib/widgets/detection_overlay.dart']+="\n'#\u0024trackId · '";
        self.assertIn('Overlay still exposes ids/percentages',check_source(src))
    def test_missing_data_regression(self):
        src=self._content();src['lib/screens/monitor_screen_components.dart']=src['lib/screens/monitor_screen_components.dart'].replace("temp == null ? '—'", "temp == null ? '0°C'")
        self.assertIn('Unavailable temperatures are not explicit',check_source(src))
    def _content(self):
        return {p:(ROOT/p).read_text(encoding='utf-8') for p in ['lib/screens/monitor_screen_portrait.dart','lib/screens/monitor_screen_multicamera.dart','lib/screens/monitor_screen_components.dart','lib/widgets/detection_overlay.dart']}
