# Vigia IA 1.0.257+257 — Detector YOLO26s no receptor

O Vigia IA ganhou suporte experimental ao YOLO26s (Ultralytics, AGPL-3.0) no aparelho que **recebe** o vídeo. Continua possível receber imagens de outro celular, Minha Câmera/MCRP, RTSP e ESP32 e executar a IA no receptor, sem processamento de visão artificial no transmissor.

O workflow tenta exportar YOLO26s para TFLite automaticamente. Se a exportação falhar, o aplicativo mantém EfficientDet-Lite2, Lite0 e SSD MobileNet V1. A seleção real fica nos diagnósticos. Não afirmar que o YOLO26s rodou sem confirmação do APK e do aparelho.

## Pendente

- Flutter analyze e testes em CI.
- Confirmar exportação e inferência YOLO26s em aparelho Dimensity 920.
- Avaliar licença AGPL-3.0 ao distribuir o APK/modelo ou manter a aplicação privada.
