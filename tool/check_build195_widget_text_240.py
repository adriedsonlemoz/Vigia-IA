#!/usr/bin/env python3
"""Ensure CI #195 text expectations match the unchanged production widgets.

This is a source-level companion check; flutter test in CI is authoritative.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def audit(source: str, pill: str, strip_tests: str, pill_tests: str) -> list[str]:
    errors: list[str] = []
    # The TextSpan representation produces one combined text widget, not a
    # separate Text child for the number and a second Text child for its unit.
    for fragment in (
        'Text.rich(',
        'TextSpan(\n                    children: [',
        'text: value,',
        "const TextSpan(text: ' ')",
        'text: unit,',
    ):
        if fragment not in source:
            errors.append(f'widget da telemetria perdeu composicao: {fragment}')
    if strip_tests.count("expect(find.text('19.8 km/h'), findsOneWidget);") != 2:
        errors.append('dois testes de telemetria devem validar valor e unidade juntos')
    if "expect(find.text('19.8'), findsOneWidget);" in strip_tests:
        errors.append('expectativa antiga do numero isolado reapareceu')
    if "'${reading?.source ?? 'Sem leitura'} · '" not in pill:
        errors.append('formato original da fonte no velocimetro mudou')
    if "'${heading == null ? 'rumo --' : '${heading!.round()}°'}'" not in pill:
        errors.append('formato original do rumo no velocimetro mudou')
    if "expect(find.text('GPS · 92°'), findsOneWidget);" not in pill_tests:
        errors.append('expectativa do indicador de rumo nao corresponde ao widget')
    if "expect(find.text('GPS · rumo 92°'), findsOneWidget);" in pill_tests:
        errors.append('expectativa de palavra rumo inexistente reapareceu')
    return errors


def check() -> list[str]:
    return audit(
        (ROOT / 'lib/widgets/map_telemetry_strip.dart').read_text(encoding='utf8'),
        (ROOT / 'lib/widgets/map_status_indicators.dart').read_text(encoding='utf8'),
        (ROOT / 'test/map_telemetry_strip_test.dart').read_text(encoding='utf8'),
        (ROOT / 'test/map_status_indicators_test.dart').read_text(encoding='utf8'),
    )


if __name__ == '__main__':
    problems = check()
    if problems:
        raise SystemExit('FALHA buildfix Android-APK-195: ' + '; '.join(problems))
    print('Buildfix 240: 3 expectativas textuais alinhadas aos widgets originais.')
