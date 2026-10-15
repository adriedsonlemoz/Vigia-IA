import unittest
from pathlib import Path
from check_build201_lint_246 import check

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "lib/screens/mcrp_camera_screen.dart"


class Build201LintRegression(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = SOURCE.read_text(encoding="utf-8")

    def test_real_project(self):
        check(self.original)

    def test_inline_return_detected(self):
        broken = self.original.replace(
            "generation != _generation) {\n      return;\n    }",
            "generation != _generation) return;",
            1,
        )
        self.assertNotEqual(broken, self.original)
        with self.assertRaises(ValueError):
            check(broken)

    def test_removed_braces_detected(self):
        broken = self.original.replace(
            "generation != _generation) {\n      return;\n    }",
            "generation != _generation)\n      return;",
            1,
        )
        self.assertNotEqual(broken, self.original)
        with self.assertRaises(ValueError):
            check(broken)

    def test_lost_generation_guard_detected(self):
        broken = self.original.replace(
            "detector == null || generation != _generation) {",
            "detector == null) {",
            1,
        )
        self.assertNotEqual(broken, self.original)
        with self.assertRaises(ValueError):
            check(broken)

    def test_lint_suppression_detected(self):
        with self.assertRaises(ValueError):
            check("// ignore_for_file: curly_braces_in_flow_control_structures\n" + self.original)


if __name__ == "__main__":
    unittest.main()
