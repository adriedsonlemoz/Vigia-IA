# Vigia IA 1.0.186+186

## Entrega

Release de estabilização da 1.0.185 baseada diretamente nos logs dos builds 145 e 146. O bloqueio estava na etapa `flutter analyze`, que tratava avisos e infos como falha e impedia o pipeline de avançar.

## Ajustes aplicados

- Substituídos identificadores descartados redundantes (`__`) pelos wildcards `_` aceitos pelo analyzer atual.
- Removido o widget legado `_TelemetryDetailRow`, sem referências após o novo painel de instrumentos.
- Removido import não utilizado de `bike_sensor_snapshot.dart` no serviço de segurança de pressão.
- Mantidas intactas as funcionalidades da 1.0.185: Clima, GPS, Velocidade, Altitude, Bússola, mapa, Bike/ESP32 e modo offline.
- Nenhuma regra de lint foi desativada e o workflow não foi alterado para ignorar a análise estática.

## Evidência dos logs

- Build 145: 3 apontamentos do analyzer; exit code 1.
- Build 146: 5 apontamentos do analyzer; exit code 1.
- Os cinco apontamentos do build mais recente foram tratados na fonte.

## Versionamento

- `versionName`: `1.0.186`
- `versionCode`: `186`
- `pubspec.yaml`: `1.0.186+186`

## Validação local

- Verificação de sincronização de versão.
- Verificação preventiva do projeto.
- Validação do catálogo de áudio Android.
- Verificação de sintaxe dos scripts Bash.
- O ambiente de edição não possui Flutter/Dart; a confirmação final de `flutter analyze` e `flutter test` deve ocorrer no CI, agora com os apontamentos conhecidos removidos.
