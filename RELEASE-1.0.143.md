# Vigia IA 1.0.143+143

## Aproximação de veículos no mapa

- O PiP que reutiliza a câmera analisada pelo Monitor agora mostra o mesmo estado de aproximação já calculado pelo Modo Bike.
- São exibidos veículo detectado, aproximação, nível de risco e TTC quando disponível; veículo sem aproximação aparece como estado sem risco.
- O indicador é compacto e fica dentro do PiP, sem ocupar a área de navegação.
- Fontes abertas somente pelo mapa não exibem risco/TTC, pois não possuem o pipeline de análise do Monitor.

## Novidades da atualização

- Novo popup global de novidades, exibido apenas uma vez por `versão+build`.
- A versão real instalada é consultada no Android e o último release mostrado é armazenado localmente.
- Atualizações puladas podem ser agregadas no mesmo popup a partir do catálogo de releases.
- Estado ausente/corrompido ou falhas de persistência não impedem a abertura do aplicativo.

## Testes adicionados

- Fluxo de primeira/segunda abertura, atualização seguinte, versões puladas e dados corrompidos.
- Estado visual do PiP para risco/TTC e veículo sem aproximação.
- Regressão do estimador para preservar detecção veicular sem alterar alertas existentes.
