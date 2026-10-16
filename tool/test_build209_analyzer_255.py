import unittest
from pathlib import Path
from tool.check_build209_analyzer_255 import ROOT, validate, check


class Build209AnalyzerRegression(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.controller = (ROOT / 'lib/controllers/monitor_controller.dart').read_text(encoding='utf-8')
        cls.components = (ROOT / 'lib/screens/monitor_screen_components.dart').read_text(encoding='utf-8')
        cls.multicamera = (ROOT / 'lib/screens/monitor_screen_multicamera.dart').read_text(encoding='utf-8')
        cls.ci = (ROOT / '.github/workflows/android-apk.yml').read_text(encoding='utf-8')

    def test_current_contract(self):
        self.assertEqual(check(), [])

    def test_missing_ai_getter_detected(self):
        broken = self.controller.replace('bool get aiEnabled => _aiEnabled;', '')
        self.assertTrue(validate(broken, self.components, self.multicamera, self.ci))

    def test_accidental_divider_variable_detected(self):
        broken = self.components.replace('final dividerColor = embedded',
                                         'final dividerColor = embedded', 1)
        broken += '\nfinal dividerColor = embedded;\n'
        self.assertTrue(validate(self.controller, broken, self.multicamera, self.ci))

    def test_interpolation_lint_detected(self):
        broken = self.multicamera.replace(
            "'Análise $analysisWidth×$analysisHeight'",
            "'Análise ${analysisWidth}×${analysisHeight}'",
        )
        self.assertTrue(validate(self.controller, self.components, broken, self.ci))

    def test_analyzer_policy_preserved(self):
        broken = self.ci.replace('flutter analyze --fatal-infos --fatal-warnings',
                                 'flutter analyze')
        self.assertTrue(validate(self.controller, self.components, self.multicamera, broken))


if __name__ == '__main__':
    unittest.main()
