#!/usr/bin/env python3
"""Guard widget Text.rich unit expectations, addressing Android-APK #196.

Companion static check only. Real widget tests run on GitHub Actions.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def audit(widget: str, tests: str) -> list[str]:
    issues: list[str] = []
    for fragment in (
        'FittedBox(', 'child: Text.rich(', 'TextSpan(\n                    children: [',
        'text: value,', "const TextSpan(text: ' ')", 'text: unit,',
        "unit: altitudeMeters == null ? null : 'm'",
        "unit: gpsAccuracyMeters == null ? null : 'm'",
        "altitudeMeters!.toStringAsFixed(0)",
        "'±${gpsAccuracyMeters!.toStringAsFixed(0)}'",
    ):
        if fragment not in widget:
            issues.append('telemetria não preserva valor + unidade: ' + fragment)
    for full_text in ('553 m', '±8 m'):
        assertion = "expect(find.text('" + full_text + "'), findsOneWidget);"
        if tests.count(assertion) != 2:
            issues.append('exigir valor com unidade em layout normal e compacto: ' + full_text)
    for isolated in ('553', '±8'):
        if "expect(find.text('" + isolated + "'), findsOneWidget);" in tests:
            issues.append('teste voltou a procurar número isolado: ' + isolated)
        if "expect(find.text('" + isolated + "'), findsNothing);" not in tests:
            issues.append('teste compacto não protege contra número isolado: ' + isolated)
    if "testWidgets('layout compacto mantém altitude e precisão com unidade'," not in tests:
        issues.append('cobertura do layout compacto ausente')
    if tests.count("expect(find.text('19.8 km/h'), findsOneWidget);") != 2:
        issues.append('regressão na correção de velocidade do build 195')
    return issues


def check() -> list[str]:
    return audit(
        (ROOT / 'lib/widgets/map_telemetry_strip.dart').read_text(encoding='utf8'),
        (ROOT / 'test/map_telemetry_strip_test.dart').read_text(encoding='utf8'),
    )


if __name__ == '__main__':
    problems = check()
    if problems:
        raise SystemExit('FALHA buildfix Android-APK-196: ' + '; '.join(problems))
    print('Buildfix 241: altitude, precisão GPS e unidades validadas em layout normal/compacto.')
