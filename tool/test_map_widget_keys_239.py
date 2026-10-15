"""Mutation regression tests for missing key arguments in extracted map widgets."""
import importlib.util
from pathlib import Path
import unittest

SRC = Path(__file__).with_name('check_map_widget_keys_239.py')
SPEC = importlib.util.spec_from_file_location('check_map_widget_keys_239', SRC)
MOD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)


class ExtractedMapKeys239Tests(unittest.TestCase):
    def test_all_ten_public_widget_constructors_accept_super_key(self):
        self.assertEqual(MOD.audit(MOD.all_contents()), [])

    def test_missing_key_is_detected(self):
        base = MOD.all_contents()
        changed = dict(base)
        name = 'map_navigation_metrics.dart'
        changed[name] = base[name].replace('    super.key,\n', '', 1)
        failures = MOD.audit(changed)
        self.assertTrue(any('MapNavigationMetricCell' in item for item in failures))

    def test_one_line_widget_constructor_without_key_is_detected(self):
        base = MOD.all_contents()
        changed = dict(base)
        name = 'map_zoom_controls.dart'
        changed[name] = base[name].replace('super.key, ', '', 1)
        failures = MOD.audit(changed)
        self.assertTrue(any('MapControlGap' in item for item in failures))

    def test_missing_widget_class_is_detected(self):
        base = MOD.all_contents()
        changed = dict(base)
        name = 'map_status_indicators.dart'
        changed[name] = base[name].replace('class MapSystemHud extends StatelessWidget {', 'class MissingMapSystemHud extends StatelessWidget {', 1)
        failures = MOD.audit(changed)
        self.assertTrue(any('MapSystemHud' in item for item in failures))


if __name__ == '__main__':
    unittest.main()
