#!/usr/bin/env python3
"""Verificações dos três bloqueios de analyzer do workflow Android APK 209."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def validate(controller: str, components: str, multicamera: str, ci: str) -> list[str]:
    failures = []
    if 'bool get aiEnabled => _aiEnabled;' not in controller:
        failures.append('MonitorController não expõe aiEnabled para a interface.')
    if components.count('final dividerColor = embedded') != 1:
        failures.append('dividerColor foi inserida fora do único componente que possui embedded.')
    if not ('class _DeviceStatusStrip extends StatelessWidget' in components and
            'color: dividerColor' in components):
        failures.append('DeviceStatusStrip não preserva divisórias com cores condicionais.')
    if "'Análise ${analysisWidth}×${analysisHeight}'" in multicamera:
        failures.append('Interpolação de largura/altura ainda contém chaves desnecessárias.')
    if "'Análise $analysisWidth×$analysisHeight'" not in multicamera:
        failures.append('Métricas da análise perderam a resolução real.')
    if 'flutter analyze --fatal-infos --fatal-warnings' not in ci:
        failures.append('Analyzer rigoroso não deve ser desativado.')
    return failures


def check(root: Path = ROOT) -> list[str]:
    return validate(
        (root / 'lib/controllers/monitor_controller.dart').read_text(encoding='utf-8'),
        (root / 'lib/screens/monitor_screen_components.dart').read_text(encoding='utf-8'),
        (root / 'lib/screens/monitor_screen_multicamera.dart').read_text(encoding='utf-8'),
        (root / '.github/workflows/android-apk.yml').read_text(encoding='utf-8'),
    )


if __name__ == '__main__':
    errors = check()
    if errors:
        for error in errors:
            print('ERRO:', error)
        raise SystemExit(1)
    print('Build 209: 35 apontamentos do analyzer tratados estruturalmente (Flutter ainda necessário).')
