#!/usr/bin/env python3
"""Verifica destinos locais de import/export/part, mesmo sem Flutter SDK.

É uma checagem de existência de arquivos, não um parser/analisador Dart.
Não tenta validar símbolos, tipos, imports de plugins nem código gerado.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIRECTIVE = re.compile(r"^\s*(?:import|export|part)\s+['\"]([^'\"]+)['\"]", re.MULTILINE)
SCANNED = ('lib', 'test', 'integration_test')


def missing_imports(root: Path) -> list[str]:
    missing = []
    for folder in SCANNED:
        base = root / folder
        if not base.exists():
            continue
        for source in sorted(base.rglob('*.dart')):
            content = source.read_text(encoding='utf-8')
            for uri in DIRECTIVE.findall(content):
                if uri.startswith('package:vigiaia/'):
                    target = root / 'lib' / uri.removeprefix('package:vigiaia/')
                elif uri.startswith(('dart:', 'package:')):
                    continue  # SDK e dependências externas são validados pelo Flutter.
                elif ':' not in uri:  # import relativo/part/export
                    target = source.parent / uri
                else:
                    continue  # URI externa não é um arquivo local.
                if not target.is_file():
                    missing.append(f'{source.relative_to(root)} -> {uri}')
    return missing


def main() -> int:
    missing = missing_imports(ROOT)
    if missing:
        print('Destinos Dart locais ausentes:')
        for item in missing:
            print(f'  {item}')
        return 1
    print('Imports/exports/parts locais: destinos encontrados (checagem parcial).')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
