#!/usr/bin/env python3
"""Testes de contrato e mutação preventivos para a 1.0.251."""
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_live_lazy_map_251 import ROOT, validate

class LiveLazyMap251(unittest.TestCase):
    def setUp(self):
        self.read = lambda f: (ROOT / f).read_text(encoding='utf-8')

    def test_current_contract(self):
        validate(self.read)

    def test_detects_map_auto_start_regression(self):
        monitor = self.read('lib/screens/monitor_screen.dart')
        monitor = monitor.replace('unawaited(_controller.initialize());',
                                  'unawaited(_controller.initialize());\n    unawaited(_initializeMiniMap(requestPermission: false));')
        with self.assertRaises(AssertionError):
            validate(lambda f: monitor if f == 'lib/screens/monitor_screen.dart' else self.read(f))

    def test_detects_live_picker_regression(self):
        ui = self.read('lib/screens/home_screen_redesign.dart')
        ui = ui.replace('onTap: () => unawaited(_startLocalCamera()),',
                        'onTap: () => unawaited(_chooseCameraForLive()),')
        with self.assertRaises(AssertionError):
            validate(lambda f: ui if f == 'lib/screens/home_screen_redesign.dart' else self.read(f))

    def test_detects_location_guard_regression(self):
        ui = self.read('lib/screens/monitor_screen_landscape_dashboard.dart')
        ui = ui.replace('if (!mounted || !_monitorMapActivated) return;',
                        'if (!mounted) return;', 1)
        with self.assertRaises(AssertionError):
            validate(lambda f: ui if f == 'lib/screens/monitor_screen_landscape_dashboard.dart' else self.read(f))

if __name__ == '__main__':
    unittest.main()
