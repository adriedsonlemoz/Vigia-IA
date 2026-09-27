# Vigia IA 1.0.187+187

## Objetivo

Estabilizar a suíte de testes após o build 147, mantendo intactas as funcionalidades da 1.0.186.

## Diagnóstico do build 147

- `flutter analyze`: aprovado, sem apontamentos.
- `flutter test`: 2 falhas em `test/update_news_service_test.dart`.
- As duas falhas esperavam build `185`, embora o catálogo atual já estivesse corretamente em `186`.

## Ajustes

- O teste do catálogo atual usa `AppMetadata.build` como fonte de verdade.
- O teste de exibição única da versão instalada usa `AppMetadata.version` e `AppMetadata.build` em vez de duplicar números de release.
- Verificadores e empacotador foram atualizados para `1.0.187+187`.
- Nenhuma lógica de mapa, Bike/ESP32, IA, sensores ou funcionamento offline foi alterada.
