# Vigia IA 1.0.264+264 · Correção do Android APK 218

## Causa

O CI exportava YOLO26s com PyTorch 2.13, enquanto a biblioteca `litert-torch` ainda referenciava a operação ATen `cholesky`, removida do PyTorch. O pip também instalou torch 2.13 com torchvision 0.29, causando incompatibilidade adicional.

## Correções

- Prepara par consistente `torch==2.13.0`, `torchvision==0.28.0`, `litert-torch==0.9.4`.
- Adapta somente o exportador para referências `aten.cholesky` legadas, apontando ao operador moderno `aten.linalg_cholesky`. O runtime Android não muda.
- Usa `ai-edge-litert` para validar o modelo e mantém release bloqueada até YOLO26s verdadeiro ser exportado.
- Substitui a URL HTTP 403 do EfficientDet-Lite2 pela rota oficial Google MediaPipe.
- Acrescenta testes de regressão para o exportador.

## Limites de validação

O `flutter analyze` já passou no workflow 218. O binário LiteRT do YOLO26s e a compilação Android devem ser confirmados no workflow seguinte. A correção foi feita no código-fonte e não é evidência de APK gerado.
