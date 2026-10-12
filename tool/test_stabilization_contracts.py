"""Testes de mutação dos verificadores leves, independentes de Flutter."""
from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_ci_contract import CiContractError, ROOT, validate
from check_import_targets import missing_imports


class CiContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workflow = (ROOT / '.github/workflows/android-apk.yml').read_text(encoding='utf-8')
        cls.wrapper = (ROOT / 'android/gradle/wrapper/gradle-wrapper.properties').read_text(encoding='utf-8')

    def test_baseline(self):
        validate(self.workflow, self.wrapper)

    def test_analyzer_removed(self):
        with self.assertRaises(CiContractError):
            validate(self.workflow.replace('flutter analyze', 'echo analisar'), self.wrapper)

    def test_tests_removed(self):
        with self.assertRaises(CiContractError):
            validate(self.workflow.replace('flutter test --reporter expanded --coverage', 'echo testar'), self.wrapper)

    def test_signing_before_tests(self):
        start = self.workflow.index('      - name: Preparar assinatura release')
        end = self.workflow.index('      - name: Build APKs release', start)
        prefix = self.workflow[:start]
        signing = self.workflow[start:end]
        misplaced = prefix.replace('      - name: Testes', signing + '      - name: Testes', 1) + self.workflow[end:]
        with self.assertRaises(CiContractError):
            validate(misplaced, self.wrapper)

    def test_apk_metadata_verification_removed(self):
        with self.assertRaises(CiContractError):
            validate(self.workflow.replace("element.get('versionCode') != version_code", 'False'), self.wrapper)

    def test_gradle_wrapper_mismatch(self):
        with self.assertRaises(CiContractError):
            validate(self.workflow, self.wrapper.replace('gradle-9.1.0-', 'gradle-9.2.0-'))

    def test_missing_signature_verification(self):
        with self.assertRaises(CiContractError):
            validate(self.workflow.replace('apksigner" verify', 'apksigner" bad'), self.wrapper)


class ImportTargetTests(unittest.TestCase):
    def test_real_project(self):
        self.assertEqual(missing_imports(ROOT), [])

    def test_local_import_missing(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'lib').mkdir()
            (root / 'lib/a.dart').write_text("import 'missing.dart';\n", encoding='utf-8')
            self.assertEqual(missing_imports(root), ['lib/a.dart -> missing.dart'])

    def test_package_import_and_external_package(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'test').mkdir()
            (root / 'lib').mkdir()
            (root / 'test/a_test.dart').write_text(
                "import 'package:vigiaia/services/missing.dart';\n"
                "import 'package:flutter_test/flutter_test.dart';\n", encoding='utf-8'
            )
            self.assertEqual(missing_imports(root), ['test/a_test.dart -> package:vigiaia/services/missing.dart'])


class TelemetryHudContracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.screen = (ROOT / 'lib/screens/map_monitoring_screen.dart').read_text(encoding='utf-8')
        cls.policy = (ROOT / 'lib/services/map_telemetry_policy.dart').read_text(encoding='utf-8')

    def test_hud_uses_only_fresh_gps_for_accuracy_and_altitude(self):
        self.assertIn('final liveGps = MapTelemetryPolicy.freshPoint(current);', self.screen)
        self.assertIn('altitudeMeters: liveGps?.altitudeMeters,', self.screen)
        self.assertIn('validAccuracyMeters(liveGps?.accuracyMeters)', self.screen)
        self.assertIn('gpsIsFresh: liveGps != null,', self.screen)
        self.assertIn('gpsHasFix: current != null,', self.screen)

    def test_compass_gps_heading_requires_live_fix(self):
        self.assertIn('gpsHeadingDegrees: MapTelemetryPolicy.gpsHeadingDegrees(live)', self.screen)
        self.assertIn('routeHeadingDegrees: live == null ? null : _routeHeadingFor(live)', self.screen)
        self.assertIn('static MapRoutePoint? freshPoint(', self.policy)

    def test_closed_panel_updates_freshness_via_shared_tick(self):
        self.assertIn('final ValueNotifier<int> _telemetryPanelTick', self.screen)
        self.assertIn('_telemetryPanelTick.value += 1;', self.screen)
        self.assertIn('_telemetryPanelTick,', self.screen)


if __name__ == '__main__':
    unittest.main()
