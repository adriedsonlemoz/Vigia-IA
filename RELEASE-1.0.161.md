# Vigia IA 1.0.161+161

## Escopo

Correção focada no contrato da popup `Novidades da atualização` e na remoção de uma dependência de API de teste do MapLibre no renderer 3D. Nenhuma nova etapa funcional foi iniciada.

## Alterações

- `UpdateNewsCatalog.current` agora contém somente a release 1.0.161.
- `UpdateNewsService` seleciona apenas a release exatamente igual à versão instalada; versões puladas não são agregadas.
- O diálogo de Novidades remove a mensagem de múltiplas atualizações acumuladas.
- Testes cobrem salto de versões, estado ausente/corrompido e ausência de fallback para releases antigas.
- `MapNavigation3DView` remove o uso de `StyleController.getLayerIds()` e mantém a camada de prédios 3D com estado interno + `addLayer()`.
- Metadados, User-Agents, Sobre/Mudanças, README, CHANGELOG, ARCHITECTURE, VALIDATION e verificadores sincronizados.

## Popup de Novidades

A popup desta versão contém exclusivamente melhorias da 1.0.161 e não inclui bugs, correções técnicas históricas nem itens de versões anteriores. O histórico completo permanece em `Sobre > Mudanças`.

## Validação local

Executar `python3 tool/check_version_sync.py`, `bash -n tool/verify_project.sh` e `bash tool/verify_project.sh`. Flutter/Dart devem ser reconfirmados no workflow quando não estiverem disponíveis no ambiente local.
