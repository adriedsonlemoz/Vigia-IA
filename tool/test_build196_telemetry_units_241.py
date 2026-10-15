#!/usr/bin/env python3
"""Regression checks for the #196 unit/text source contract."""
from pathlib import Path
import importlib.util
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    'build196_telemetry', ROOT / 'tool/check_build196_telemetry_units_241.py')
module = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(module)


class TelemetryUnitContracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.widget = (ROOT / 'lib/widgets/map_telemetry_strip.dart').read_text(encoding='utf8')
        cls.tests = (ROOT / 'test/map_telemetry_strip_test.dart').read_text(encoding='utf8')

    def test_baseline(self):
        self.assertEqual([], module.audit(self.widget, self.tests))

    def test_detects_isolated_altitude(self):
        bad = self.tests.replace("find.text('553 m'), findsOneWidget", "find.text('553'), findsOneWidget", 1)
        self.assertTrue(module.audit(self.widget, bad))

    def test_detects_isolated_accuracy(self):
        bad = self.tests.replace("find.text('±8 m'), findsOneWidget", "find.text('±8'), findsOneWidget", 1)
        self.assertTrue(module.audit(self.widget, bad))

    def test_detects_lost_units_in_widget(self):
        bad = self.widget.replace("unit: altitudeMeters == null ? null : 'm'", "unit: null", 1)
        self.assertTrue(module.audit(bad, self.tests))

    def test_detects_lost_compact_case(self):
        bad = self.tests.replace("testWidgets('layout compacto mantém altitude e precisão com unidade',", "testWidgets('layout compacto sem proteção',", 1)
        self.assertTrue(module.audit(self.widget, bad))


if __name__ == '__main__':
    unittest.main()
