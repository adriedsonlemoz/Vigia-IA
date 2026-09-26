# Vigia IA 1.0.162+162

## Escopo

Esta entrega ajusta o contrato do controle rápido de áudio do mapa e mantém a popup de Novidades exclusiva da versão instalada atual.

## Implementação

- `IA/Detecções` atua no `MonitorController`, que concentra o pipeline real de IA/voz.
- A segunda câmera continua sendo uma visualização auxiliar e não recebe um estado de voz artificial.
- `AlertDeliveryService` preserva `respectGlobalVoice` como parâmetro público com inicialização direta.
- `UpdateNewsCatalog.current` contém somente `1.0.162+162`.
- O histórico completo permanece em `Sobre > Mudanças`.
- O verificador preventivo bloqueia chamadas de `setVoiceEnabled()` no `SecondaryCameraController`.

## Validação

- `python3 tool/check_version_sync.py`
- `bash tool/verify_project.sh`
- `flutter analyze`, `flutter test` e build Android Release devem ser confirmados no workflow com Flutter disponível.

## Popup de Novidades

A popup desta versão contém exclusivamente novidades da 1.0.162. Não inclui histórico de versões anteriores.
