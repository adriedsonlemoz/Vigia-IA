#!/usr/bin/env python3
"""Prevent recurrence of Flutter analyze lint in APK 215."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCREEN = ROOT / 'lib/screens/monitor_screen_multicamera.dart'
WORKFLOW = ROOT / '.github/workflows/android-apk.yml'


def check_source(source: str, workflow: str) -> None:
    guard = re.compile(
        r'if\s*\(\s*_sameSource\(_controller\.sourceConfig,\s*source\)\s*&&\s*'
        r'_secondaryController\s*==\s*null\s*\)\s*\{\s*return\s*;\s*\}',
        re.MULTILINE,
    )
    assert len(guard.findall(source)) == 1, (
        'APK 215: o guard de troca de camera requer chaves { return; }.'
    )
    assert 'flutter analyze --fatal-infos --fatal-warnings' in workflow, (
        'Nao desativar a verificacao rigorosa do Flutter.'
    )
    assert 'ignore: curly_braces_in_flow_control_structures' not in source, (
        'Nao ocultar o lint com ignore.'
    )


if __name__ == '__main__':
    check_source(SCREEN.read_text(encoding='utf-8'), WORKFLOW.read_text(encoding='utf-8'))
    print('APK 215: if do seletor frontal com chaves e analyzer rigoroso preservado.')
