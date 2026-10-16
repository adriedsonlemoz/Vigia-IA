#!/usr/bin/env python3
"""Protege contra definições duplicadas de getters no controlador da IA (#213)."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
FILE = ROOT / 'lib/controllers/monitor_controller_ai_support.dart'

def duplicated_getters(source: str) -> list[str]:
    # Restrito aos getters deste arquivo-part, sem contar usos da propriedade.
    names = re.findall(r'^\s*(?:[A-Za-z_][A-Za-z0-9_<>,? ]*\s+)?get\s+([A-Za-z_][A-Za-z0-9_]*)\s*=>', source, re.M)
    return sorted({name for name in names if names.count(name) > 1})

def check() -> None:
    content = FILE.read_text(encoding='utf-8')
    duplicates = duplicated_getters(content)
    assert not duplicates, f'Getters duplicados em {FILE.name}: {duplicates}'
    assert len(re.findall(r'\bget\s+activeDetectorModel\s*=>', content)) == 1, 'activeDetectorModel deve ter somente uma declaração'
    assert len(re.findall(r'\bget\s+detectorModelPreference\s*=>', content)) == 1, 'preferência do modelo não deve ser duplicada'

if __name__ == '__main__':
    check()
    print('APK 213: getters do controlador de IA sem duplicidade')
