# Vigia IA 1.0.157+157

Etapa 2 da evolução do mapa: seletor de veículo compacto e correção da área segura inferior no Android.

## Implementado

- O seletor `Bicicleta / Moto / Carro / A pé` foi convertido de quatro linhas grandes para uma grade 2 × 2.
- Cada opção usa cartão praticamente quadrado com ícone grande, nome e check na seleção atual.
- O último perfil realmente utilizado é persistido por `MapViewSettingsService` e restaurado como padrão após reiniciar o aplicativo.
- O bottom sheet reserva `MediaQuery.viewPadding.bottom` mais margem interna, cobrindo navegação Android por três botões e por gestos.
- Em telas de baixa altura/paisagem, o conteúdo pode rolar em vez de ficar escondido atrás do sistema.

## Preservado

- Bicicleta continua usando `bicycle`, Moto `motorcycle`, Carro `auto` e A pé `pedestrian` no roteamento.
- Rota, recálculo, GPS, voz, POIs, gravação, mapas offline, botão 3D/2D e estabilização/fallback do MapLibre foram mantidos.
- Nenhuma parte da Etapa 3 (reformulação dos cards superiores) foi antecipada.

## Validação

- `MapUxPolicy` ganhou teste específico para a margem inferior baseada em `viewPadding.bottom`.
- `tool/verify_project.sh` verifica grade 2 × 2, persistência do último modo, Safe Area inferior e manutenção dos quatro perfis reais.
- `python3 tool/check_version_sync.py`: **aprovado** localmente.
- `bash tool/verify_project.sh`: **aprovado** localmente.
- JSONs de identidade e sintaxe do verificador shell: **aprovados**; nenhum APK/AAB presente no fonte.
- Flutter/Dart não estão instalados neste ambiente local; `flutter analyze`, `flutter test` e build Android release precisam ser reconfirmados pelo workflow.
- O ZIP de código-fonte não deve conter APK/AAB.
