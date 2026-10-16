#!/usr/bin/env python3
"""Detects return-on-multiline-if regression reported by CI build 207."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MONITOR = ROOT / 'lib/screens/monitor_screen_fullscreen.dart'
WORKFLOW = ROOT / '.github/workflows/android-apk.yml'


def check_source(source: str, workflow: str) -> None:
    guard = re.compile(
        r'if\s*\(\s*_mapRoute\.monitorVisibility\s*==\s*mode\s*&&\s*'
        r'\(mode\s*==\s*MonitorMapVisibilityMode\.hidden\s*\|\|\s*'
        r'_monitorMapActivated\)\s*\)\s*\{\s*return\s*;\s*\}',
        re.MULTILINE,
    )
    assert len(guard.findall(source)) == 1, (
        'Guard de visibilidade do mapa exige bloco { return; } para flutter analyze.'
    )
    assert 'flutter analyze --fatal-infos --fatal-warnings' in workflow, (
        'Analise estatica rigorosa nao pode ser desativada.'
    )
    assert 'ignore: curly_braces_in_flow_control_structures' not in source, (
        'Nao ocultar warning via ignore.'
    )


if __name__ == '__main__':
    check_source(MONITOR.read_text(encoding='utf-8'), WORKFLOW.read_text(encoding='utf-8'))
    print('Build 207: guard fullscreen com chaves e analyzer rigoroso preservados.')
