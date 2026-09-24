# Vigia IA 1.0.107+107

## Correção

- Corrige o Android-APK-75 na configuração Android/Gradle.
- O módulo `app` passa a seguir o template oficial do Flutter 3.44.9: sem `kotlin-android` explícito e com `kotlin.compilerOptions` para JVM 17.
- Mantém a geração de universal + armeabi-v7a + arm64-v8a + x86_64 em uma única compilação.
- Mantém Build Cache, paralelismo e `setup-gradle@v6`.
- Adiciona verificações preventivas para impedir retorno do DSL Kotlin que causou a falha.

## Evidência do Android-APK-75

- `flutter analyze`: sem issues.
- testes: 176 aprovados.
- falha anterior: compilação do `build.gradle.kts` com DSL Kotlin legado sob Gradle 9.1.0 / AGP 9.0.1.

## Versão

- `1.0.107+107`
