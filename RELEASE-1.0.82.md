# Vigia IA 1.0.82+82

Distribuição Android em APKs diretos por arquitetura.

## Downloads da Release

- `VigiaIA-v1.0.82+82-arm64-v8a.apk`: recomendado para a maioria dos celulares Android atuais;
- `VigiaIA-v1.0.82+82-armeabi-v7a.apk`: compatibilidade com aparelhos Android mais antigos de 32 bits;
- `VigiaIA-v1.0.82+82-x86_64.apk`: emuladores e dispositivos compatíveis;
- `VigiaIA-v1.0.82+82-universal.apk`: contém todas as arquiteturas e serve quando não for possível identificar a ABI.

Os quatro arquivos são publicados como assets da GitHub Release. Assim, ao selecionar um APK, o navegador recebe o `.apk` diretamente; o ZIP é reservado apenas aos relatórios técnicos do workflow.

## Auditoria

O workflow mantém `apk-size-report.txt`, `flutter-dependencies.txt` e `gradle-release-dependencies.txt` em um artifact separado. Isso preserva a investigação de tamanho sem misturar diagnósticos com o arquivo de instalação.

## Validação

Cada APK é assinado com a keystore de release e validado com `apksigner` antes da publicação.
