"""Regressão negativa do aviso de analyzer da versão 1.0.231 (CI #191)."""
from pathlib import Path
import unittest
from check_build191_lints import ROOT, TARGET, BODY, GUARD, violations


class Build191LintsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = (ROOT / TARGET).read_text(encoding='utf-8')

    def test_corrected_guard_has_block(self):
        self.assertEqual(violations(self.source), [])

    def test_original_unbraced_return_is_rejected(self):
        matched = GUARD.search(self.source)
        self.assertIsNotNone(matched)
        body = BODY.match(self.source[matched.end():])
        self.assertIsNotNone(body)
        broken = self.source[:matched.end()] + ' return;' + self.source[matched.end() + body.end():]
        self.assertTrue(violations(broken))

    def test_missing_guard_is_rejected(self):
        changed = self.source.replace('_connectivity.isOffline ||', '_connectivity.isOnline ||', 1)
        self.assertTrue(violations(changed))


if __name__ == '__main__':
    unittest.main()
