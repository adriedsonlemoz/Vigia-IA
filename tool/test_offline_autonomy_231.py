"""Mutacoes negativas dos contratos offline e bateria."""
import unittest
from check_offline_autonomy_231 import ROOT, violations

class OfflineAutonomy231Test(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        read = lambda path: (ROOT / path).read_text(encoding='utf-8')
        cls.content = [
            read('lib/services/offline_map_coverage_policy.dart'),
            read('lib/screens/map_monitoring_screen.dart'),
            read('lib/services/map_connectivity_service.dart'),
            read('lib/screens/map_monitoring_offline_support.dart'),
            read('lib/widgets/offline_map_manager_sheet.dart'),
            read('test/offline_map_coverage_policy_test.dart'),
        ]

    def test_baseline(self):
        self.assertEqual(violations(*self.content), [])

    def test_missing_corridor_guard_rejected(self):
        data = self.content.copy()
        data[0] = data[0].replace("package.downloadKind == 'route'", 'false')
        self.assertTrue(violations(*data))

    def test_reintroduced_duplicate_dns_rejected(self):
        data = self.content.copy()
        data[3] += '\n// checkNow(force: true)\n'
        self.assertTrue(violations(*data))

    def test_lost_offline_polling_rejected(self):
        data = self.content.copy()
        data[2] = data[2].replace('offlineProbeInterval = const Duration(seconds: 60)', 'offlineProbeInterval = const Duration(seconds: 15)')
        self.assertTrue(violations(*data))
