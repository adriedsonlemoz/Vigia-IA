#!/usr/bin/env python3
import unittest
from pathlib import Path
from tool.check_build215_camera_lint_261 import check_source

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'lib/screens/monitor_screen_multicamera.dart').read_text(encoding='utf-8')
WORKFLOW = (ROOT / '.github/workflows/android-apk.yml').read_text(encoding='utf-8')


class Build215CameraLint261(unittest.TestCase):
    def test_real_project(self):
        check_source(SOURCE, WORKFLOW)

    def test_missing_braces_is_rejected(self):
        broken = SOURCE.replace(
            '_secondaryController == null) {\n      return;\n    }',
            '_secondaryController == null) return;',
        )
        self.assertNotEqual(broken, SOURCE)
        with self.assertRaises(AssertionError):
            check_source(broken, WORKFLOW)

    def test_analyzer_must_stay_strict(self):
        with self.assertRaises(AssertionError):
            check_source(SOURCE, WORKFLOW.replace(' --fatal-infos', ''))

    def test_lint_suppression_is_rejected(self):
        with self.assertRaises(AssertionError):
            check_source(SOURCE + '\n// ignore: curly_braces_in_flow_control_structures\n', WORKFLOW)


if __name__ == '__main__':
    unittest.main()
