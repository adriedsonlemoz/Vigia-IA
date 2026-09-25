# Vigia IA 1.0.146+146

## Offline aprimorado

- Monitoramento leve da conectividade enquanto o mapa está aberto.
- Perda de rede preserva a última rota viária conhecida em vez de descartá-la.
- Sem rota anterior, o app mostra somente a direção ao destino e deixa essa limitação explícita.
- POIs offline são ativados imediatamente usando o melhor pacote salvo para a posição atual.
- Quando a internet retorna, POIs e rota viária tentam se recuperar automaticamente.
- Um mapa MBTiles disponível pode assumir automaticamente o fundo quando a internet cair, inclusive se o modo estava forçado como Online; a preferência salva não é alterada.

## Revisão visual do mapa

- Margens e controles reduzidos para ampliar a área útil do mapa.
- Zoom, filtros rápidos e atalhos Perto/Região/Rota mais compactos.
- Banner de navegação e barra de percurso ocupam menos altura.
- PiPs recebem redução temporária adicional durante navegação e reservas recalibradas para retrato/paisagem.
- O próprio chip de camada informa Sem internet, Offline automático e Reconectando rota sem criar outro overlay.

## Arquitetura e testes

- Novos `MapConnectivityService`, `MapConnectivityStatus` e `MapOfflineNavigationPolicy`.
- Integração offline complementar isolada em `map_monitoring_offline_support.dart` para não aumentar ainda mais a tela principal.
- Testes adicionados para transições online/offline, tolerância a falha isolada e política de fallback seguro.
- Versionamento e documentação sincronizados em `1.0.146+146`.
