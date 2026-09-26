# Vigia IA 1.0.153+153

Correção do Android-APK-116 após a primeira etapa da navegação 3D.

## Corrigido

- `flutter analyze` não deve mais falhar pelas cinco ocorrências de `unnecessary_non_null_assertion` em `MapMonitoringScreen`.
- Removidos operadores `!` redundantes de `navigationTarget` onde o fluxo já garante destino não nulo.

## Preservado

- Navegação em perspectiva 3D com MapLibre.
- Seleção Bicicleta, Moto, Carro ou A pé e roteamento por perfil.
- Alternativas, voz, recálculo, POIs, câmeras e fallback 2D/MBTiles.

Esta versão é um buildfix e não adiciona uma nova etapa funcional do mapa 3D.
