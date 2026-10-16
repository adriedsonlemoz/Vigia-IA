#!/usr/bin/env python3
import unittest
from pathlib import Path
from tool.check_build221_ai_lint_267 import check_source

ROOT = Path(__file__).resolve().parents[1]
UI = (ROOT / 'lib/screens/monitor_screen_ai_tools.dart').read_text()
STATE = (ROOT / 'lib/screens/monitor_screen.dart').read_text()
CI = (ROOT / '.github/workflows/android-apk.yml').read_text()


class Build221AiLint267Test(unittest.TestCase):
    def test_current_contract(self):
        check_source(UI, STATE, CI)

    def test_direct_protected_state_call_rejected(self):
        altered = UI.replace('_updateAiDiagnosticState(', 'setState(', 1)
        self.assertNotEqual(altered, UI)
        with self.assertRaises(AssertionError):
            check_source(altered, STATE, CI)

    def test_missing_state_helper_rejected(self):
        with self.assertRaises(AssertionError):
            check_source(UI, STATE.replace('void _updateAiDiagnosticState(',
                                           'void _renamedAiDiagnosticState('), CI)

    def test_analyzer_must_stay_strict(self):
        with self.assertRaises(AssertionError):
            check_source(UI, STATE, CI.replace('--fatal-warnings', ''))

    def test_lint_suppression_rejected(self):
        with self.assertRaises(AssertionError):
            check_source(UI + '\n// ignore: invalid_use_of_protected_member', STATE, CI)


if __name__ == '__main__':
    unittest.main()
