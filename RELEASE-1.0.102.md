# Vigia IA 1.0.102+102

## Objetivo

Facilitar a configuração da fonte de mapas offline para que o usuário entenda onde obter a API key da Stadia Maps sem sair procurando manualmente o painel correto.

## Alterações

- O diálogo **Configurar fonte** ganhou o botão **Como conseguir a chave?**.
- A ajuda mostra um passo a passo para:
  - abrir o painel oficial da Stadia Maps;
  - entrar ou criar a conta;
  - abrir **Manage Properties**;
  - acessar **Authentication Configuration**;
  - gerar a API key;
  - copiar a chave e colar no Vigia IA.
- Botão **Abrir painel** abre diretamente `https://client.stadiamaps.com/dashboard/`.
- Botão **Instruções oficiais** abre `https://docs.stadiamaps.com/authentication/#api-keys`.
- Se o Android não conseguir abrir o navegador, o link oficial é copiado automaticamente para o clipboard.
- A chave continua protegida pelo Android Keystore e não é incluída no código-fonte.
- `NativePlatformService` e `MainActivity` receberam uma ponte restrita a URLs HTTP/HTTPS para abrir links externos.

## Compatibilidade preservada

- Mapas offline MBTiles, download direto, limite de 100 MB, seleção visual de região, rota persistente, GPX, câmera flutuante, Monitor e IA foram preservados sem alteração funcional.

## Validação local

- `python3 tool/check_version_sync.py` deve passar em `1.0.102+102`.
- `bash tool/verify_project.sh` deve passar.
- Flutter, Dart e Android SDK não estão disponíveis neste ambiente; `flutter analyze`, `flutter test` e o build do APK devem ser confirmados pelo workflow.
