# Vigia IA 1.0.194+194

Esta entrega corrige os cinco avisos `curly_braces_in_flow_control_structures` encontrados pelo `flutter analyze` do build 155. Os condicionais apontados no mapa, na camada OSM de vias e na política de alertas de velocidade agora usam blocos explícitos, sem mudança funcional.

O mapa Bike, ETA, seleção livre, modos de foco, rádio online, alertas, notificação de navegação e painel dos pneus da 1.0.193 foram preservados. A tela de Novidades e os metadados estão sincronizados com `1.0.194+194`.

As verificações estruturais locais foram executadas. `flutter analyze`, `flutter test`, build Android e validação em dispositivo ainda dependem do workflow, pois o SDK Flutter/Android não está instalado neste ambiente.
