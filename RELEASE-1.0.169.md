# Vigia IA 1.0.169+169 — refinamento final do mapa 3D

Esta versão conclui o plano atual de reformulação do mapa sem iniciar funcionalidades futuras.

## Entrega funcional

- Câmera 3D adaptativa por Bicicleta, Moto, Carro e A pé, com zoom, pitch, centro, bearing, animação e área à frente ajustados por velocidade, próxima manobra e aproximação ao destino.
- Suavização do centro e do bearing baseada apenas em coordenadas/headings reais; dead-zones reduzem tremor e um limite angular evita giros bruscos em curvas/manobras.
- Norte/Direção/Rota preservados, inclusive prioridade de sensor em baixa velocidade e GPS/rota em movimento. Sem fonte real, nenhum heading novo é inventado.
- Gestos manuais continuam pausando o acompanhamento; Centralizar retoma o follow explicitamente.
- Rota, casing, posição e destino receberam reforço visual por tema e são mantidos acima das extrusões de prédios.
- Prédios 3D continuam best-effort e só usam source/source-layer realmente declaradas pelo style; não há dependência fixa de `openmaptiles`.
- Terrain/elevation real não foi habilitado: `maplibre 0.3.6` fornece Raster DEM/hillshade, mas a API Flutter pública usada pelo projeto não expõe controle seguro de terrain 3D e não há fonte DEM configurada. Nenhum relevo foi simulado.
- Diagnóstico ampliado com duração por estágio, style/provedor/fallback, PlatformView, pitch/zoom/bearing, modo/fonte de heading, prédios, capacidade de terrain e motivo real/sanitizado do fallback 2D.
- Inicialização por estágios, timeout individual, primeiro frame real, fallback de style, Hybrid Composition e fallback final 2D foram preservados.
- Popup Novidades contém exclusivamente as mudanças visíveis da versão 1.0.169+169 e continua aparecendo uma vez por versão instalada.

## Compatibilidade preservada

HUD compacto, Velocidade, Altitude, Bússola, GPS, Clima ESP32/online, transporte, Busca, Categorias, Alertas, Áudio, offline/MBTiles, gravação, GPX, temas, Manual/Sistema/Dia-noite, POIs, Locais próximos, câmeras local/remota/ESP32, dock lateral, Valhalla e fallback online/offline permanecem no mesmo fluxo.

## Validação esperada

Executar `python3 tool/check_version_sync.py`, `bash tool/verify_project.sh` e as validações de JSON/scripts/workflow/artefatos. Flutter/Dart devem ser executados somente quando os SDKs estiverem disponíveis no ambiente.
