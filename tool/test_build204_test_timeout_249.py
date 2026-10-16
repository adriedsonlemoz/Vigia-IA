#!/usr/bin/env python3
"""Mutation tests for the Android-APK #204 ten-minute hang prevention."""
import unittest
from pathlib import Path
from check_build204_test_timeout_249 import validate

ROOT = Path(__file__).resolve().parents[1]
TEST = (ROOT / 'test/mcrp_saved_cameras_screen_test.dart').read_text(encoding='utf-8')
WORKFLOW = (ROOT / '.github/workflows/android-apk.yml').read_text(encoding='utf-8')
STORE = (ROOT / 'test/mcrp_saved_cameras_store_test.dart').read_text(encoding='utf-8')


class Build204RegressionTests(unittest.TestCase):
    def test_contract_passes(self):
        validate(TEST, WORKFLOW, STORE)

    def test_rejects_file_io_in_widget(self):
        with self.assertRaisesRegex(ValueError, 'I/O real'):
            validate(TEST + '\nFile("/tmp");\n', WORKFLOW, STORE)

    def test_rejects_fake_async_directory_create(self):
        with self.assertRaisesRegex(ValueError, 'I/O real'):
            validate(TEST + '\nDirectory.systemTemp.createTemp("x");\n', WORKFLOW, STORE)

    def test_rejects_missing_test_timeout(self):
        with self.assertRaisesRegex(ValueError, 'timeout explícito'):
            validate(TEST, WORKFLOW.replace(' --timeout 120s', ''), STORE)

    def test_rejects_missing_workflow_guard(self):
        with self.assertRaisesRegex(ValueError, 'limite global'):
            validate(TEST, WORKFLOW.replace('timeout-minutes: 7', 'timeout-minutes: 35'), STORE)

    def test_rejects_lost_persistence_coverage(self):
        with self.assertRaisesRegex(ValueError, 'persistência'):
            validate(TEST, WORKFLOW, '')


if __name__ == '__main__':
    unittest.main()
