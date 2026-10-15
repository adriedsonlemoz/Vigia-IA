# Vigia IA 1.0.243+243 | Correção do workflow Android-APK-198

## Diagnóstico

`flutter analyze --fatal-infos --fatal-warnings` falhou na versão 1.0.242+242 com exatamente três avisos informativos:

1. `lib/services/camera_registry_service.dart:138` (`prefer_interpolation_to_compose_strings`): a URL `/control/<token>/status` era formada por concatenação com `+`.
2. `lib/services/minha_camera_live_url.dart:18` (`curly_braces_in_flow_control_structures`): `if` de rejeição de URL sem bloco `{}`.
3. `lib/sources/minha_camera_mjpeg_source.dart:3` (`unnecessary_import`): import de `dart:typed_data` coberto por `package:flutter/foundation.dart`.

A validação preventiva 1.0.242 passou, mas o GitHub Actions abortou **antes de executar os testes Flutter e de gerar o APK**.

## Modificações

- A URL de status mantém a mesma rota e token, mas usa `final controlPath` e interpolação `'$controlPath/status'`, sem concatenação.
- O `if` ganha chaves, preservando o retorno `null` para URLs inválidas.
- Removido apenas o import desnecessário. `Uint8List` permanece acessível pelo Flutter Foundation.
- Novo gate `tool/check_build198_lints_243.py` e cinco testes de mutação em `tool/test_build198_lints_243.py` para prevenir os três avisos e preservar o endpoint.
- Gate histórico `tool/check_minha_camera_integration_242.py` permanece ativo e agora verifica a rota de status refatorada e versões sequenciais a partir da 242.
- Versão 1.0.243+243, Android versionCode, metadados, User-Agents, catálogo de Novidades, Sobre, README, CHANGELOG e relatórios sincronizados.

Não há modificação na decodificação MJPEG, na leitura/autenticação dos QR Codes, no pipeline de IA, na captura de quadros ou no gerenciamento de câmera.

## Validação pendente

- Executar `flutter analyze --fatal-infos --fatal-warnings`, `flutter test` e geração do APK em CI. O SDK Flutter/Android não está disponível neste ambiente.
- Teste nos celulares Redmi A3 e Redmi Note 11 Pro+ com MJPEG, opção de IA ativada e desativada, troca Wi-Fi/hotspot e reconexão.
