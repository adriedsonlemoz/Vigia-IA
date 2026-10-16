import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def source(p): return (ROOT / p).read_text(encoding='utf8')

class FrontPrimaryAndPerformance260(unittest.TestCase):
    def test_front_is_primary_from_both_selectors(self):
        screen = source('lib/screens/monitor_screen_multicamera.dart')
        self.assertIn('await _selectLocalPrimarySource(_frontCameraTestSource());', screen)
        self.assertIn('_selectLocalPrimarySource(_frontCameraTestSource()),', screen)
        self.assertNotIn('_selectSecondaryCamera(_frontCameraTestSource())', screen)
        self.assertNotIn('await _replaceSecondarySource(_frontCameraTestSource())', screen)

    def test_single_physical_camera_released_before_switch(self):
        screen = source('lib/screens/monitor_screen_multicamera.dart')
        section = screen.split('Future<void> _selectLocalPrimarySource')[1].split('Future<void> _selectPrimaryCamera')[0]
        self.assertLess(section.index('await _replaceSecondarySource(null);'), section.index('await _controller.switchSource(source);'))
        self.assertIn('await previous.suspend();', screen)

    def test_local_frame_source_tracks_front_lens(self):
        local = source('lib/sources/local_camera_source.dart')
        core = source('lib/controllers/monitor_controller.dart')
        shared = source('lib/services/shared_local_camera_service.dart')
        self.assertIn('frontCamera: config.isFrontCameraTest', core)
        self.assertIn('frontCamera: frontCamera,', local)
        self.assertIn('CameraLensDirection.front', shared)
        self.assertIn('await _startUnlocked(frontCamera: keepFront)', shared)

    def test_throttle_does_not_limit_native_preview(self):
        core = source('lib/controllers/monitor_controller.dart')
        shared = source('lib/services/shared_local_camera_service.dart')
        self.assertIn('requestedInterval < const Duration(milliseconds: 900)', source('lib/controllers/monitor_controller_ai_support.dart'))
        self.assertIn('_effectiveMonitorAnalysisInterval(this, config)', core)
        self.assertIn('CameraPreview(active, key: ObjectKey(active))', shared)
        self.assertIn('if (_converting || _consumers.isEmpty) return;', shared)

    def test_ignore_legacy_secondary_front_after_resume(self):
        self.assertIn('secondarySource.isFrontCameraTest', source('lib/screens/monitor_screen.dart'))

if __name__ == '__main__': unittest.main()
