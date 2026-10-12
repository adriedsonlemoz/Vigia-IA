#!/usr/bin/env python3
"""Regressão estrutural de três guardas que falharam no analyzer do CI #187.

Não é parser Dart e NÃO substitui flutter analyze. Verifica as guardas
específicas e exige bloco explícito em cada retorno antecipado.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
GUARDS = (
    ('lib/screens/map_monitoring_screen.dart', r'''if\s*\(\s*!MapTelemetryPolicy\.isRecentTimestamp\(\s*reading\.recordedAt,\s*maximumAge:\s*const\s+Duration\(seconds:\s*3\),?\s*\)\s*\)''', 'return null;'),
    ('lib/services/map_destination_ranking.dart', r'''if\s*\(\s*!item\.id\.startsWith\('nominatim:'\)\s*&&\s*!item\.id\.startsWith\('reverse:'\)\s*\)''', 'return item;'),
    ('lib/services/map_destination_ranking.dart', r'''if\s*\(\s*!const\s*<String>\s*\{[^}]*'relation'[^}]*\}\.contains\(type\)\s*\|\|\s*int\.tryParse\(number\)\s*==\s*null\s*\)''', 'return null;'),
)


def find_violations(read_file):
    violations = []
    for path, pattern, statement in GUARDS:
        code = read_file(path)
        matches = list(re.finditer(pattern, code, flags=re.S))
        if len(matches) != 1:
            violations.append(f'{path}: guarda esperada não identificada unicamente ({len(matches)})')
            continue
        next_text = code[matches[0].end():]
        # Lint: o corpo do if deve iniciar com uma abertura de bloco;
        # o fechamento não deve ser omitido após o único retorno.
        body = re.compile(r'^\s*\{\s*' + re.escape(statement) + r'\s*\}', re.S)
        if body.match(next_text) is None:
            violations.append(f'{path}: condicional precisa de bloco {{ ... }}: {statement}')
    return violations


def main():
    violations = find_violations(lambda path: (ROOT / path).read_text(encoding='utf-8'))
    if violations:
        raise SystemExit('Build #187 regressão: ' + '; '.join(violations))
    print('Regressões do analyzer Android APK #187: 3/3 guardas com chaves.')


if __name__ == '__main__':
    main()
