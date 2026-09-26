# Vigia IA 1.0.166+166

## Escopo
ETAPA 3 do plano do mapa: Clima Inteligente — ESP32 + online.

## Entrega
- Quinto mini-card `Clima` no HUD superior, com temperatura e origem ESP32/Online/Misto.
- Temperatura, umidade e pressão podem vir de sensores ESP32 reais; dados ausentes são complementados online sem inferências indevidas.
- Open-Meteo fornece condição, vento, precipitação e previsão de chuva quando a rede está disponível.
- Cache local, atualização manual e indicação de dados antigos reduzem consultas online.
- Popup central mostra somente valores existentes e identifica a fonte de cada grupo.
- Voz do clima reutiliza o sistema de áudio/TTS já existente e ganhou controle próprio no popup rápido do mapa.
- Suporte de telemetria ambiental ESP32 preparado para temperatura, umidade e pressão.

## Validação local
`python3 tool/check_version_sync.py`, `bash -n tool/verify_project.sh`, `bash tool/verify_project.sh`, validação dos JSONs, workflow único e varredura de APK/AAB foram aprovados. Flutter/Dart não estão disponíveis no ambiente local; `flutter analyze`, `flutter test` e o build release devem ser confirmados no CI.
