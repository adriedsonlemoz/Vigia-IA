# Vigia IA 1.0.209+209 — Desempenho da câmera remota

- Compressão do transmissor com limite de uma execução por vez e descarte de frames em sobrecarga.
- Processamento reduzido quando nenhum aparelho está recebendo vídeo.
- Atualização de frames no receptor independente da análise por IA.
- Decodificação RGB para IA em uma tarefa de cada vez, evitando fila e acúmulo de memória.
- Leitura de proporção da imagem sem decodificação integral.
- Câmera física permanece ativa na troca entre modo ocioso e visualização remota.

## Validação exigida

`tool/verify_project.sh` deve passar; o GitHub Actions ainda precisa confirmar `flutter analyze`, `flutter test` e APK. Testar estabilidade de FPS, memória e bateria em dois celulares Android reais. O transporte continua JPEG/HTTP, sem implementação de codec de vídeo por hardware nesta versão.
