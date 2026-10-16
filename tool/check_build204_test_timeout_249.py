#!/usr/bin/env python3
"""Prevent the fake-async widget filesystem stall seen in Android APK #204."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
TEST = ROOT / 'test/mcrp_saved_cameras_screen_test.dart'
WORKFLOW = ROOT / '.github/workflows/android-apk.yml'
STORE_TEST = ROOT / 'test/mcrp_saved_cameras_store_test.dart'


def validate(test: str, workflow: str, storage_test: str) -> None:
    expected = [
        'class _MemoryMcrpCamerasStore extends McrpSavedCamerasStore',
        'McrpCameraScreen(savedStore: store)',
        'Future<List<SavedMcrpCamera>> load() async',
        'Future<List<SavedMcrpCamera>> remove(String liveUrl) async',
        "find.byTooltip('Remover câmera salva')",
        "find.text('Remover câmera salva?')",
        'find.textContaining(token), findsNothing',
        'timeout: const Timeout(Duration(seconds: 40))',
    ]
    for marker in expected:
        if marker not in test:
            raise ValueError(f'Contrato de regressão widget ausente: {marker}')
    forbidden = ('Directory.systemTemp.createTemp(', '.writeAsString(',
                 'File(', 'tester.runAsync(', "import 'dart:io';")
    for marker in forbidden:
        if marker in test:
            raise ValueError(f'I/O real ou mecanismo obsoleto no testWidgets: {marker}')
    if re.search(r'await\s+(?:store\.save|File\(|Directory\.)', test):
        raise ValueError('Operação de I/O real dentro do testWidgets')
    if ('createTemp' not in storage_test or 'await store.save' not in storage_test
            or 'await store.remove' not in storage_test):
        raise ValueError('Testes reais de persistência não foram preservados')
    match = re.search(r'^      - name: Testes\n(?P<step>.*?)(?=^      - name:|\Z)',
                      workflow, re.MULTILINE | re.DOTALL)
    if not match:
        raise ValueError('Etapa Flutter Testes não encontrada')
    step = match.group('step')
    if not re.search(r'^\s*timeout-minutes:\s*7\s*$', step, re.MULTILINE):
        raise ValueError('Etapa Flutter Testes sem limite global de 7 minutos')
    if not re.search(r'run:\s*flutter test --reporter expanded --coverage --timeout (?:2m|120s)', step):
        raise ValueError('Flutter test sem timeout explícito de 2 minutos')
    if 'flutter analyze --fatal-infos --fatal-warnings' not in workflow:
        raise ValueError('flutter analyze rígido foi removido')


def main() -> int:
    validate(TEST.read_text(encoding='utf-8'),
             WORKFLOW.read_text(encoding='utf-8'),
             STORE_TEST.read_text(encoding='utf-8'))
    print('Build 204: testWidgets sem I/O real; testes de disco isolados; timeouts de CI verificados.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
