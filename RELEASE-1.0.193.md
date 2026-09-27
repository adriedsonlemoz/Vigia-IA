# Vigia IA 1.0.193+193

A tela do mapa Bike agora traz três níveis de foco, tela inteira com hora/bateria, seleção livre de destino com toque longo, ETA e velocidade ESP32/Hall ou GPS. Alertas de velocidade são configuráveis. A notificação Android de navegação, a camada opcional de vias/rios marcados no OSM, a vista topográfica, rádio online com estações salvas e painel central dos pneus completam a tela. A inicialização protegida e o HUD compacto das versões 1.0.189–1.0.192 foram preservados.

A camada de vias depende de tags OSM e internet; hillshade depende da fonte e de chave configurada. Não há terreno 3D real. Rádio requer URL direta de stream. `flutter analyze`, `flutter test`, build Android e validação em dispositivo estão pendentes devido à ausência de SDK local.
