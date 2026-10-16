#!/usr/bin/env python3
import unittest
from pathlib import Path
from tool.check_build207_fullscreen_lint_253 import check_source

R = Path(__file__).resolve().parents[1]
SOURCE = (R / 'lib/screens/monitor_screen_fullscreen.dart').read_text(encoding='utf-8')
WORKFLOW = (R / '.github/workflows/android-apk.yml').read_text(encoding='utf-8')


class Build207FullscreenLint253(unittest.TestCase):
    def test_real_project(self):
        check_source(SOURCE, WORKFLOW)

    def test_missing_braces_fails(self):
        mutation = SOURCE.replace(
            '|| _monitorMapActivated)) {\n      return;\n    }',
            '|| _monitorMapActivated)) return;',
        )
        self.assertNotEqual(mutation, SOURCE)
        with self.assertRaises(AssertionError):
            check_source(mutation, WORKFLOW)

    def test_relaxed_analyzer_fails(self):
        with self.assertRaises(AssertionError):
            check_source(SOURCE, WORKFLOW.replace(' --fatal-infos', ''))

    def test_suppression_fails(self):
        with self.assertRaises(AssertionError):
            check_source(SOURCE + '\n// ignore: curly_braces_in_flow_control_structures\n', WORKFLOW)


if __name__ == '__main__':
    unittest.main()
