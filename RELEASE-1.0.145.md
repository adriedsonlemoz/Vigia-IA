# Vigia IA 1.0.145+145

## Avisos de proximidade de POIs

- Alertas agora validam as categorias selecionadas no momento do disparo, inclusive quando a lista carregada foi obtida antes de uma mudança de preferência.
- Distância configurável continua sendo o primeiro marco; 1 km permanece como aproximação final quando aplicável.
- Um cooldown global de 1 minuto limita sequências de avisos quando vários pontos estão próximos.
- Se um POI for descoberto já dentro de um marco menor, marcos maiores já ultrapassados são consumidos para não serem anunciados atrasados.
- Pacotes offline passam pela mesma política de alerta dos dados online.

## Navegação por voz

- Próxima manobra e distância são faladas nos marcos de 1 km, 500 m, 200 m e 80 m, com arredondamento adequado para TTS.
- O mesmo marco não é repetido continuamente a cada atualização GPS.
- Desvio confirmado da rota anuncia saída + início do recálculo; após sucesso é anunciada a nova rota.
- Chegada ao destino é anunciada somente uma vez por navegação.
- POIs e navegação usam `MapVoiceService`, que reaproveita `AlertVoiceService` e respeita as preferências globais de voz/TTS do Vigia IA.

## Testes e validação

- Adicionado `route_explorer_alert_policy_test.dart` para categorias, offline, marcos consumidos e cooldown.
- Adicionado `map_navigation_voice_policy_test.dart` para distâncias, deduplicação, prioridade de 80 m e chegada única.
- Catálogo de Novidades, tela Sobre/Mudanças, README, CHANGELOG, ARCHITECTURE, VALIDATION e metadados foram sincronizados para `1.0.145+145`.

## Validação local

- `python3 tool/check_version_sync.py`: aprovado.
- `bash tool/verify_project.sh`: aprovado.
- Workflow Android preservado sem alterações em relação à 1.0.144.
- Fonte verificado sem APK/AAB embutido.
- Flutter/Dart não estão instalados neste ambiente; analyze, testes Flutter e build Android devem ser reconfirmados pelo workflow.
