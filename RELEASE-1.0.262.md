# Vigia IA 1.0.262+262 — Ao vivo com duas câmeras grandes e telemetria compacta

- Faixa superior do Ao vivo apresenta cartões compactos somente das câmeras ligadas, com nome, porcentagem de bateria e temperatura da bateria quando existirem dados reais. "—" indica indisponibilidade.
- Se houver uma câmera, apenas um cartão e um vídeo principal; com duas fontes, dois cartões e divisão vertical em painéis de igual tamanho.
- A IA continua analisando somente a câmera principal, sem iniciar segunda inferência no transmissor ou na câmera secundária.
- Botões de escolha do modelo e diagnóstico profundo permanecem no topo.
- Identificadores # e percentuais removidos das etiquetas e listas visuais de objetos. Dados técnicos de confiança continuam disponíveis na telemetria exportada.
- Relatórios de 16/10/2026 analisados: EfficientDet-Lite0; a recepção Minha Câmera MJPEG 1920×1080 apresentou conversão média de ~225 ms, P50 de ~198 ms. Reduzir resolução transmitida pode melhorar a fluidez, sem mudar a implementação da captura nesta versão.
- Não há APK nesta entrega. É necessário validar build/Flutter e testes reais no dispositivo.
