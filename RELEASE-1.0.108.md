# Vigia IA 1.0.108+108

## Correção

- Corrige o Android-APK-76 em `:app:processReleaseResources`.
- Restaura `mipmap/ic_launcher`, `style/LaunchTheme` e `style/NormalTheme` referenciados pelo Manifest.
- Versiona fundo de lançamento, temas claro/escuro e launcher adaptativo para não depender do bootstrap em builds normais.
- Reforça a checagem de integridade do Android no workflow e no `verify_project.sh`.
- Mantém universal + armeabi-v7a + arm64-v8a + x86_64 em uma única compilação, com cache e paralelismo.

## Evidência do Android-APK-76

- `flutter analyze`: passou.
- testes: passaram antes do build.
- falha anterior: AAPT não encontrava `mipmap/ic_launcher`, `style/LaunchTheme` e `style/NormalTheme`.
- o build já avançou por cerca de 4 minutos antes dessa falha, demonstrando que a correção Gradle/Kotlin da 1.0.107 foi superada.

## Versão

- `1.0.108+108`
