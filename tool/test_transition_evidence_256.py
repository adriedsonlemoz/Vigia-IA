import unittest
from pathlib import Path

from tool.check_transition_evidence_256 import check_sources

ROOT = Path(__file__).resolve().parents[1]
T = (ROOT / 'lib/services/object_tracker.dart').read_text(encoding='utf-8')
C = (ROOT / 'lib/controllers/monitor_controller.dart').read_text(encoding='utf-8')
S = (ROOT / 'lib/controllers/monitor_controller_event_support.dart').read_text(encoding='utf-8')


class VerifiedZoneContracts(unittest.TestCase):
    def test_current(self):
        check_sources(T, C, S)

    def test_missing_exit_guard(self):
        with self.assertRaises(AssertionError):
            check_sources(T.replace('if (!verifiedZoneTransitionsOnly &&', 'if ('), C, S)

    def test_motion_evidence(self):
        with self.assertRaises(AssertionError):
            check_sources(T.replace('isMoving?.call(detection) ?? false', 'true'), C, S)

    def test_confirmation(self):
        with self.assertRaises(AssertionError):
            check_sources(T.replace('track.pendingZoneHits < 2', 'track.pendingZoneHits < 1'), C, S)

    def test_controller_uses_safe_mode(self):
        with self.assertRaises(AssertionError):
            check_sources(T, C.replace('verifiedZoneTransitionsOnly: true', 'verifiedZoneTransitionsOnly: false'), S)

    def test_cooldown(self):
        with self.assertRaises(AssertionError):
            check_sources(T, C, S.replace('Duration(seconds: 20)', 'Duration(seconds: 1)'))


if __name__ == '__main__':
    unittest.main()
