#!/usr/bin/env python3
"""Guarda os dois ajustes que desbloqueiam o flutter analyze do APK #179."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
source = (root / 'lib/screens/map_monitoring_screen.dart').read_text(encoding='utf-8')
if 'onTap: (_, _) => _dismissFreeMapSelection(),' not in source:
    raise SystemExit('Callback FlutterMap deve usar parâmetros descartados (_, _).')
# `compact` é uma variável de instância/argumento em tempo de execução e não deve aparecer
# dentro de um estilo `const TextStyle(...)`.
for m in re.finditer(r'const\s+TextStyle\s*\(', source):
    # Limitar a declaração a um argumento de TextStyle, não ao arquivo inteiro.
    following = source[m.end():]
    closing = following.find(')')
    if closing >= 0 and re.search(r'fontSize\s*:\s*compact\s*\?', following[:closing]):
        raise SystemExit('TextStyle const não pode depender da variável compact.')
print('Buildfix do mapa #179 validado (const e curingas).')
