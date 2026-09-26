# Vigia IA 1.0.164+164

## Escopo
Somente ETAPA 2 do plano do mapa: telemetria superior compacta e clicável.

## Entrega
- Velocidade, Altitude, Bússola e GPS passam a usar mini-cards de 42–48 px, liberando mais área do mapa.
- Os quatro indicadores são clicáveis e abrem detalhes específicos.
- Velocidade mostra leitura atual, média e máxima da sessão, fonte e precisão de velocidade quando fornecida pelo GPS.
- Altitude mostra valor atual, precisão vertical, fonte e última atualização.
- GPS mostra status, precisão horizontal, coordenadas, velocidade, heading real quando disponível, altitude e última leitura.
- Disponibilidade e precisões reais de velocidade, altitude e heading são preservadas do Geolocator até a UI; dados ausentes aparecem como indisponíveis.
- Contagem de satélites não é exibida porque a API atual do projeto não fornece essa métrica.
- Bússola e os modos Norte/Direção/Rota da 1.0.163 permanecem preservados.
- Popup Novidades exclusiva da versão atual.

## Compatibilidade
Mapa 2D, MapLibre 3D, fallback, offline/MBTiles, rota, perfis de transporte, voz, POIs, câmeras, gravação e diagnóstico permanecem preservados.

## Validação local
Executar `python3 tool/check_version_sync.py`, `bash -n tool/verify_project.sh` e `bash tool/verify_project.sh`. Flutter/Dart devem ser executados em CI/ambiente com SDK disponível.
