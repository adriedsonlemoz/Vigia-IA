# Vigia IA 1.0.122+122

## Escopo

Esta entrega prioriza a experiência de conexão e configuração do ESP32 antes da próxima etapa do mapa.

## Mudanças

- Novo `Esp32SetupWizard` em tela inteira com cinco etapas: conexão, identificação, capacidades, configuração e revisão.
- Busca/teste guiado do módulo com fallback para `http://192.168.4.1` e `http://esp32.local`.
- Endereço e chave ficam em seção manual, evitando expor detalhes técnicos antes de serem necessários.
- Capacidades informadas pelo firmware são aproveitadas automaticamente; câmera e sensores continuam independentes.
- Hall, temperatura e pneus exibem seus ajustes apenas quando selecionados; telemetria e ativação ficam em opções avançadas.
- Revisão final permite novo teste de conexão e o módulo ainda pode ser salvo offline.
- Ao finalizar, a tela salva o módulo, testa a conexão e tenta aplicar `/config` quando houver firmware online compatível.
- A tela vazia deixa de exibir dois botões de conexão; o FAB aparece somente depois que já existe ao menos um módulo.
- Corrigido Android-APK-90: removido import redundante de `package:flutter/foundation.dart` em `esp32_telemetry_service.dart`.
- Corrigida a leitura de `capabilities: []` para preservar módulos sem sensores selecionados, sem restaurar sensores padrão indevidamente.

## Validação local

- `python3 tool/check_version_sync.py`
- `bash tool/verify_project.sh`
- Integridade do ZIP final

O ambiente desta entrega não possui Flutter/Android SDK. `flutter analyze`, `flutter test` e o build APK devem ser reconfirmados pelo workflow.
