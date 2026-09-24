# Vigia IA 1.0.117+117

Entrega de reorganização da Home e consolidação dos papéis operacionais.

## Alterações

- Home 2x2: Ao vivo, Transmissão, Remoto e ESP32.
- Cinco acessos rápidos em uma única linha.
- Bike passa a ser perfil/configuração em Ajustes > Bike e economia.
- Migração de modo Bike legado para Ao vivo sem apagar preferências Bike.
- Emulador de sensores movido para a engrenagem da tela ESP32.
- Transmissão recebe engrenagem de configuração Bike/economia e bateria local.
- Política de transmissão separada da análise: 10 FPS padrão; Bike 10/6/3 FPS.
- JPEG preservado em níveis conservadores para equilíbrio entre autonomia e legibilidade.

## Validação local

Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`. Flutter/Android SDK precisam ser confirmados pelo workflow para analyzer, testes e APK.
