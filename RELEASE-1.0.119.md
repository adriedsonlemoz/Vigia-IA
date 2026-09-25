# Vigia IA 1.0.119+119

## Interface

- Incorpora os quatro ícones transparentes do redesign nos cards **Ao vivo**, **Transmissão**, **Remoto** e **ESP32** da Home.
- Corrige os filtros do Histórico com quatro botões compactos e alinhados.
- Move **Monitorar** para o cabeçalho do card de câmera, ao lado do nome, reduzindo o espaço vazio; a abertura com segunda câmera permanece no menu.

## Validação

- `python3 tool/check_version_sync.py`
- `bash tool/verify_project.sh`
- Integridade do ZIP final
- `flutter analyze`, `flutter test` e build Android precisam ser confirmados pelo workflow quando o SDK estiver disponível.
