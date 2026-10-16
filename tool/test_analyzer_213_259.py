import unittest
from tool.check_analyzer_213_259 import duplicated_getters, check

class Analyzer213259Test(unittest.TestCase):
    def test_actual_file(self):
        check()

    def test_fails_for_duplicate_model_getter(self):
        source = '  String get activeDetectorModel => _detector.activeModel;\n  String get activeDetectorModel => _detector.activeModel;\n'
        self.assertEqual(duplicated_getters(source), ['activeDetectorModel'])

    def test_unrelated_getter_not_flagged(self):
        source = '  String get activeDetectorModel => _detector.activeModel;\n  bool get aiEnabled => _aiEnabled;\n'
        self.assertEqual(duplicated_getters(source), [])

if __name__ == '__main__':
    unittest.main()
