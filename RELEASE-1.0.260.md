# Vigia IA 1.0.260+260: frontal principal e fluidez

## 1.0.260+260: frontal como principal e fluidez do Ao vivo (2026-10-16)

- Ao selecionar **Câmera frontal**, ela substitui a câmera principal e ocupa toda a área de vídeo, com análise de IA nessa fonte; a frontal não é mais aberta como miniatura PiP usando outro CameraController.
- O pipeline compartilhado CameraX seleciona a lente solicitada e preserva a lente também ao reiniciar; segundas fontes locais concorrentes são encerradas antes da troca.
- A conversão RGB da câmera local usa intervalo mínimo de 900 ms, independente da prévia nativa, para reduzir sobrecarga de CPU e risco de congelamento; isso pode reduzir a frequência de análise.
- Quadros descartados por detector ocupado deixam de reconstruir a tela desnecessariamente.
- Relatório real da 1.0.259 confirmou **EfficientDet-Lite0**, mediana de 1,25 FPS analisado, 214 ms de inferência e 459 ms de atraso total; YOLO26s não estava carregado. Corrigir a cadência não prova FPS superior: objetivo é manter a interface fluida.
- Preservados seletor de modelos, diagnóstico/exportação de relatório e transmissão sem IA.
- Build, hardware e estabilidade final dependem de validação no Android.

