# Vigia IA 1.0.154+154

Correção do Android-APK-117 no build release da primeira etapa da navegação 3D.

## Corrigido

- O subprojeto `maplibre_android 0.3.6` não conseguia resolver o plugin Gradle `org.jlleitschuh.gradle.ktlint` porque a chamada publicada não informa uma versão.
- `android/settings.gradle.kts` passa a fornecer `org.jlleitschuh.gradle.ktlint` `14.2.0` em `pluginManagement`.

## Preservado

- Navegação em perspectiva 3D com MapLibre.
- Seleção Bicicleta, Moto, Carro ou A pé e roteamento por perfil.
- Alternativas, voz, recálculo, POIs, câmeras e fallback 2D/MBTiles.

Esta versão é um buildfix de infraestrutura e não adiciona uma nova etapa funcional ao mapa 3D.
