#!/usr/bin/env python3
"""APK 221: extensões Dart não podem usar State.setState (protected)."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXTENSION = ROOT / 'lib/screens/monitor_screen_ai_tools.dart'
STATE = ROOT / 'lib/screens/monitor_screen.dart'
WORKFLOW = ROOT / '.github/workflows/android-apk.yml'


def check_source(extension: str, state: str, workflow: str) -> None:
    assert 'extension _MonitorAiTools on _MonitorScreenState' in extension, (
        'A extensão de ferramentas IA precisa continuar acessível ao Monitor.')
    assert not re.search(r'(?<![\w])setState\s*\(', extension), (
        'APK 221: não chamar o método protegido setState dentro da extensão.')
    assert extension.count('_updateAiDiagnosticState(') == 4, (
        'Os quatro pontos de atualização do diagnóstico devem usar o helper.')
    pattern = re.compile(
        r'void\s+_updateAiDiagnosticState\s*\(\s*VoidCallback\s+update\s*\)\s*'
        r'\{\s*if\s*\(\s*!mounted\s*\)\s*return\s*;\s*setState\s*\(\s*update\s*\)\s*;\s*\}',
        re.S,
    )
    assert len(pattern.findall(state)) == 1, (
        'O helper deve residir em _MonitorScreenState com guarda mounted.')
    assert state.index('class _MonitorScreenState extends State<MonitorScreen>') < \
        state.index('void _updateAiDiagnosticState(') < state.index('void _refresh()'), (
        'O helper precisa estar dentro da classe State.')
    assert 'flutter analyze --fatal-infos --fatal-warnings' in workflow, (
        'O lint completo deve continuar obrigatório no GitHub Actions.')
    assert not re.search(r'ignore(?:_for_file)?:\s*invalid_use_of_protected_member',
                         extension + '\n' + state), (
        'Não é permitido mascarar o aviso do analisador com ignore.')


if __name__ == '__main__':
    check_source(EXTENSION.read_text(), STATE.read_text(), WORKFLOW.read_text())
    print('APK 221: quatro atualizações IA usam helper no State e lint rigoroso permanece ativo.')
