"""Testes negativos da prevenção específica dos lints do Android APK #187."""
import unittest
from pathlib import Path
from check_build187_lints import ROOT, GUARDS, find_violations


class Build187LintsTest(unittest.TestCase):
    def setUp(self):
        self.sources = {
            path: (ROOT / path).read_text(encoding='utf-8')
            for path, _, _ in GUARDS
        }

    def test_original_code_corrected(self):
        self.assertEqual(find_violations(self.sources.__getitem__), [])

    def test_each_return_without_braces_is_rejected(self):
        from re import search, compile, escape, S
        for path, pattern, statement in GUARDS:
            with self.subTest(path=path, statement=statement):
                edited = dict(self.sources)
                source = edited[path]
                found = search(pattern, source, flags=S)
                self.assertIsNotNone(found)
                trailing = source[found.end():]
                body = compile(r'^\s*\{\s*' + escape(statement) + r'\s*\}', S)
                matched = body.match(trailing)
                self.assertIsNotNone(matched)
                edited[path] = source[:found.end()] + ' ' + statement + trailing[matched.end():]
                self.assertTrue(find_violations(edited.__getitem__))

    def test_missing_guard_is_rejected(self):
        edited = dict(self.sources)
        path, pattern, _ = GUARDS[0]
        edited[path] = edited[path].replace('!MapTelemetryPolicy.isRecentTimestamp', '!LegacyTelemetryPolicy.isRecentTimestamp', 1)
        self.assertTrue(find_violations(edited.__getitem__))


if __name__ == '__main__':
    unittest.main()
