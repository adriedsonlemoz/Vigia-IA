# Vigia IA 1.0.263+263 — YOLO26s como detector padrão

- YOLO26s é a preferência inicial na análise do receptor. A opção Automático continua disponível e mantém YOLO26s em primeiro lugar.
- O GitHub Actions agora exige a exportação e validação do YOLO26s em LiteRT, em vez de publicar uma release silenciosamente sem ele.
- Após a compilação, cada APK precisa conter um arquivo YOLO26s real com pelo menos 3 MB; o modelo da pasta-fonte é apenas um marcador temporário.
- Fallback em tempo de execução preservado: se o YOLO26s falhar no aparelho ou ficar excessivamente lento, o detector usa EfficientDet-Lite2/Lite0/SSD. O diagnóstico informa o modelo realmente ativo.
- Transmissão continua sem inferência; análise é feita exclusivamente no receptor.
- A troca de modelo e os relatórios continuam disponíveis na tela Ao vivo.

## Verificação

- Contratos preventivos para default YOLO e CI fail-closed acrescentados.
- Testes Android reais e velocidade no Dimensity 920 ainda dependem do GitHub Actions e do aparelho.

## Licença

Pesos e tecnologia YOLO Ultralytics podem estar sujeitos a AGPL-3.0 ou licença comercial. Verificar obrigações antes da distribuição.
