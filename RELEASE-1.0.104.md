# Vigia IA 1.0.104+104

Entrega focada no fluxo de mapas e câmeras sobrepostas.

## Alterações

- Painel completo para API key da Stadia Maps com Colar, Ver, Copiar, Testar, Trocar e Remover.
- Status explícito de chave configurada e valor mascarado; o campo de nova chave não expõe automaticamente o segredo salvo.
- Teste mínimo de credencial com resposta/latência e integração ao contador local de créditos quando válido.
- Seleção de região offline com modos Mapa/Área e zoom − / z / + na parte inferior.
- Telemetria do mapa completo transferida para chips compactos superiores; barra inferior reduzida ao botão Iniciar/Encerrar rota.
- Pausar/Continuar e Exportar GPX preservados no menu de ações da rota.
- PiP principal sem faixa Local, com mostrar/ocultar e adaptação dinâmica vertical/horizontal.
- Segunda câmera encaminhada ao mapa completo como PiP independente, inicialmente abaixo da principal e livre para arrastar.

## Validação

Executar `tool/check_version_sync.py`, `tool/verify_project.sh`, `flutter analyze`, `flutter test` e o build Android no workflow.
