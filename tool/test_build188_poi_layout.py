"""Mutacoes negativas para o layout adaptativo do POI (build #188)."""
import unittest
from check_build188_poi_layout import WIDGET, TEST, violations


class PoiLayout188Test(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.widget = WIDGET.read_text(encoding='utf-8')
        cls.tests = TEST.read_text(encoding='utf-8')

    def test_baseline(self):
        self.assertEqual(violations(self.widget, self.tests), [])

    def test_unbounded_text_rejected(self):
        modified = self.widget.replace('Flexible(\n              child: Text(', 'Text(', 1)
        self.assertNotEqual(modified, self.widget)
        self.assertTrue(violations(modified, self.tests))

    def test_missing_small_screen_regression_rejected(self):
        modified = self.tests.replace('[320, 360, 412]', '[360]')
        self.assertNotEqual(modified, self.tests)
        self.assertTrue(violations(self.widget, modified))

    def test_missing_responsive_buttons_rejected(self):
        modified = self.widget.replace('constraints.maxWidth < 310', 'false')
        self.assertNotEqual(modified, self.widget)
        self.assertTrue(violations(modified, self.tests))
