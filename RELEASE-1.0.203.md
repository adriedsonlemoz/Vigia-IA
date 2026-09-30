# Vigia IA 1.0.203+203

Correção do fechamento ao escolher o Google Maps e chave própria por usuário.

## Causa do fechamento

- A meta-data `com.google.android.geo.API_KEY` estava dentro de `<activity>`; o Maps SDK lê os metadados de `<application>`. Sem achar a chave, o SDK derruba o processo ao criar o mapa, sem mensagem e sem registro no Dart.
- O workflow também não fornece `MAPS_API_KEY`, então o APK saía sem chave.

## Alterações

- Meta-data movida para `<application>` em `android/app/src/main/AndroidManifest.xml` e `tool/AndroidManifest.xml`.
- `MapMonitoringScreen` só usa `GoogleMapView` quando há chave; caso contrário avisa e mantém o mapa atual.
- Nova tela `GoogleMapsKeyScreen` (Configurações e painel do provedor do mapa) e serviço `GoogleMapsKeyService`.
- `MainActivity.kt` (e a cópia em `tool/android`) guarda a chave com `protectSecret` e a injeta em `onCreate`.
- Teste `test/google_maps_key_service_test.dart` para a validação de formato.

## Observação sobre o workflow 168

O log do workflow Android 168 terminou com `exit code 127` ao executar `./tool/bootstrap_android.sh`: o repositório não continha os arquivos do projeto Android nem o script de bootstrap. Esta entrega é o projeto completo e deve substituir o conteúdo do repositório inteiro, não apenas alguns arquivos.

## Validação

`flutter analyze`, `flutter test` e o build ainda precisam ser confirmados pelo workflow (SDK Flutter/Android indisponível no ambiente de edição).
