# Vigia IA 1.0.184+184

## Escopo

Busca incremental do mapa e integração Bike/ESP32/pressão dos pneus. Esta release não inclui o redesenho detalhado dos cards Clima, GPS, Velocidade, Altitude e Bússola, reservado para a 1.0.185.

## Alterações

- Sugestões locais/offline são filtradas imediatamente durante a digitação; Nominatim só é consultado após confirmação.
- Botão Bike adicionado ao dock do mapa, com estado visual derivado do mesmo `BikeSensorService` usado pela telemetria ESP32.
- Painel compacto exibe dianteiro e traseiro simultaneamente, limites, conexão, módulo, atualização, bateria e temperatura.
- `BikePressureSafetyService` adiciona histórico temporal por pneu e confirma perda rápida por duas leituras suspeitas.
- Limiar inicial preparado para evolução: 3 PSI ou 10% dentro de 10 segundos.
- Alertas de queda rápida incluem som, voz, banner visual não bloqueante, pressão anterior/atual e cooldown.
- Emulador passa a cobrir pressão baixa, crítica, queda rápida em cada pneu, desconexão e recuperação.
- Preservados os ajustes de compatibilidade estática existentes no ZIP-base.

## Validação

- Executar `python3 tool/check_version_sync.py`, `python3 tool/verify_audio_resource_catalog.py` e `bash tool/verify_project.sh`.
- Executar `flutter analyze` e `flutter test` no workflow/ambiente Flutter; o SDK Flutter/Dart não está instalado neste ambiente de edição.
- Confirmar em aparelho/emulador os cenários ESP32 e o comportamento do painel em retrato/paisagem.
