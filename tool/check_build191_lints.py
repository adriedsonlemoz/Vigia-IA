#!/usr/bin/env python3
"""Guarda estrutural do lint Flutter analyzer visto no Android APK #191.

O parser Dart/`flutter analyze` continua sendo a fonte de validação definitiva.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
TARGET = 'lib/screens/map_monitoring_offline_support.dart'
GUARD = re.compile(
    r'if\s*\(\s*_connectivity\.isOffline\s*\|\|\s*'
    r'_offlineMaps\.mode\s*==\s*OfflineMapMode\.offline\s*\)',
    re.S,
)
BODY = re.compile(r'^\s*\{\s*return;\s*\}', re.S)


def violations(source: str) -> list[str]:
    matches = list(GUARD.finditer(source))
    if len(matches) != 1:
        return [f'Esperada uma guarda de recuperação offline; encontradas {len(matches)}']
    if BODY.match(source[matches[0].end():]) is None:
        return ['Recuperação offline: if precisa de bloco explícito { return; }']
    return []


def main() -> None:
    source = (ROOT / TARGET).read_text(encoding='utf-8')
    errors = violations(source)
    if errors:
        raise SystemExit('Build #191: ' + '; '.join(errors))
    print('Build Android APK #191: guarda offline com chaves aprovada.')


if __name__ == '__main__':
    main()
