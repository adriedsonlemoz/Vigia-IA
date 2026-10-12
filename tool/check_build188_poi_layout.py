#!/usr/bin/env python3
"""Previne a regressao do RenderFlex overflow do workflow Android APK #188.

Checagem estrutural simples, complementar ao flutter test (nao o substitui).
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WIDGET = ROOT / 'lib/widgets/map_poi_details_sheet.dart'
TEST = ROOT / 'test/map_poi_details_sheet_test.dart'


def violations(widget=None, tests=None):
    w = WIDGET.read_text(encoding='utf-8') if widget is None else widget
    t = TEST.read_text(encoding='utf-8') if tests is None else tests
    errors = []
    pill = w.split('class _InfoPill extends StatelessWidget', 1)
    if len(pill) != 2 or 'Flexible(' not in pill[1] or 'softWrap: true' not in pill[1]:
        errors.append('_InfoPill nao limita o Text ao espaco do Row')
    if 'constraints.maxWidth < 310' not in w or 'textScale > 1.3' not in w:
        errors.append('acoes do POI nao se adaptam a tela/fonte pequena')
    if 'tester.takeException()' not in t or '[320, 360, 412]' not in t or '[1.0, 1.5]' not in t:
        errors.append('regressoes widget de 320/360/412 dp e fonte 1x/1.5x ausentes')
    return errors


if __name__ == '__main__':
    problems = violations()
    if problems:
        raise SystemExit('\n'.join(problems))
    print('Regressao de overflow da ficha POI Android APK #188: OK')
