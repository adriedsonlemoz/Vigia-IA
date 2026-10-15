#!/usr/bin/env python3
"""Mutational regressions for fatal analyzer infos from build 198."""
import importlib.util
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('build198_guard', ROOT/'tool/check_build198_lints_243.py')
mod=importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(mod)

class Build198LintTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.registry=(ROOT/'lib/services/camera_registry_service.dart').read_text(encoding='utf8')
        cls.url=(ROOT/'lib/services/minha_camera_live_url.dart').read_text(encoding='utf8')
        cls.source=(ROOT/'lib/sources/minha_camera_mjpeg_source.dart').read_text(encoding='utf8')

    def test_clean_sources(self):
        self.assertEqual([],mod.audit(self.registry,self.url,self.source))

    def test_rejects_concatenation(self):
        bad=self.registry.replace("path: '$controlPath/status'", "path: controlPath + '/status'")
        self.assertTrue(mod.audit(bad,self.url,self.source))

    def test_rejects_missing_braces(self):
        bad=self.url.replace("""        uri.hasQuery || uri.hasFragment) {
      return null;
    }""","""        uri.hasQuery || uri.hasFragment) return null;""")
        self.assertTrue(mod.audit(self.registry,bad,self.source))

    def test_rejects_unneeded_import(self):
        bad="import 'dart:typed_data';\n"+self.source
        self.assertTrue(mod.audit(self.registry,self.url,bad))

    def test_rejects_healthcheck_path_regression(self):
        bad=self.registry.replace("replaceFirst('/live/', '/control/')", "replaceFirst('/live/', '/wrong/')")
        self.assertTrue(mod.audit(bad,self.url,self.source))

if __name__=='__main__':
    unittest.main()
