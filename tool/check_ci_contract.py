#!/usr/bin/env python3
"""Guardas locais mínimos do workflow principal.

Checa gates e ordem de execução sem depender de bibliotecas Python extras.
Não valida o YAML inteiro: o próprio GitHub Actions deve fazer isso.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / '.github/workflows/android-apk.yml'
WRAPPER = ROOT / 'android/gradle/wrapper/gradle-wrapper.properties'


class CiContractError(ValueError):
    pass


def validate(workflow: str, wrapper: str) -> None:
    # O nome da etapa delimita um step: evita considerar comandos em comentário
    # ou após uma falha de validação como suficientes para aprovar o release.
    markers = list(re.finditer(r'^      - (?:name|uses):\s*(.+)$', workflow, re.M))
    steps: list[tuple[str, str]] = []
    for i, marker in enumerate(markers):
        end = markers[i + 1].start() if i + 1 < len(markers) else len(workflow)
        steps.append((marker.group(1).strip(), workflow[marker.start():end]))

    def stage(name: str) -> tuple[int, str]:
        found = [(i, body) for i, (title, body) in enumerate(steps) if title == name]
        if len(found) != 1:
            raise CiContractError(f'Etapa esperada exatamente uma vez: {name}')
        return found[0]

    def required(name: str, fragment: str) -> int:
        index, body = stage(name)
        if fragment not in body:
            raise CiContractError(f'{name}: comando obrigatório ausente: {fragment}')
        return index

    names = [
        'Dependencias',
        'Verificacao preventiva',
        'Analise estatica',
        'Baixar modelo TensorFlow Lite',
        'Testes',
        'Preparar assinatura release',
        'Build APKs release em uma unica compilacao',
        'Nomear APKs e analisar tamanho',
        'Verificar assinatura dos APKs',
        'Publicar APKs na Release',
    ]
    indices = [stage(name)[0] for name in names]
    if indices != sorted(indices):
        raise CiContractError('Gates fora da ordem: pub → verificador → analyze → testes → assinatura → build → publicação')

    required('Dependencias', 'flutter pub get')
    required('Verificacao preventiva', 'bash ./tool/verify_project.sh')
    required('Analise estatica', 'flutter analyze')
    required('Testes', 'flutter test --reporter expanded --coverage')
    required('Build APKs release em uma unica compilacao', 'gradle :app:assembleRelease')
    required('Verificar assinatura dos APKs', 'apksigner" verify')
    required('Publicar APKs na Release', 'gh release')
    required('Preparar assinatura release', 'keytool -list')
    required('Nomear APKs e analisar tamanho', "element.get('versionName') != version_name")
    required('Nomear APKs e analisar tamanho', "element.get('versionCode') != version_code")
    required('Nomear APKs e analisar tamanho', "data.get('applicationId') != 'com.vigiaia.app'")

    if 'flutter-version: \'3.44.9\'' not in workflow:
        raise CiContractError('SDK Flutter fixado inesperado: atualizar contrato ao migrar o SDK')
    gradle_match = re.search(r"^\s*gradle-version:\s*['\"]?([\d.]+)", workflow, re.M)
    wrapper_match = re.search(r'gradle-([\d.]+)-\w+\.zip', wrapper)
    if not gradle_match or not wrapper_match or gradle_match.group(1) != wrapper_match.group(1):
        raise CiContractError('Versão Gradle divergente entre workflow e wrapper Android')

    # Ainda não temos relatorio de build do runner, logo os testes precisam
    # executar mesmo que o repositório esteja temporariamente sem Secrets.
    if 'if: always()' not in stage('Salvar cobertura de testes')[1]:
        raise CiContractError('Cobertura deve ser arquivada mesmo quando testes falharem')
    if not re.search(r'^permissions:\s*\n\s*contents: write', workflow, re.M):
        raise CiContractError('Publicação release sem permissão contents: write')


def main() -> int:
    try:
        validate(WORKFLOW.read_text(encoding='utf-8'), WRAPPER.read_text(encoding='utf-8'))
    except CiContractError as exc:
        print(f'Contrato CI: FALHA: {exc}')
        return 1
    print('Contrato CI: gates, assinatura e ferramentas na ordem exigida.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
