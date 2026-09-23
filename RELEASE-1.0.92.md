# Vigia IA 1.0.92+92

## Resumo

Nova política de orientação por modo. O Vigia IA permanece vertical em todas as telas comuns, enquanto somente o modo Transmissão acompanha a posição física do celular.

## Alterações

- Adicionado `AppOrientationService` para centralizar a regra de rotação.
- Home, Histórico, Diagnóstico, Configurações, Bike, Mapas e Monitor permanecem em retrato.
- O modo Transmissão não é forçado para paisagem: ele libera as quatro orientações e acompanha o sensor do aparelho.
- Ao sair da Transmissão, o app restaura retrato antes de navegar.
- Tela inteira do Monitor deixa de forçar paisagem; continua imersiva, com Ajustar/Preencher e controles temporários.
- Rótulos atuais de “Tela inteira horizontal” foram atualizados para “Tela inteira”.

## Câmera e orientação do frame

O pipeline de captura não foi alterado. `SharedLocalCameraService` continua combinando `sensorOrientation` e `deviceOrientation`; assim, quando o transmissor é colocado deitado, a rotação enviada acompanha a posição real do aparelho sem precisar forçar a interface para paisagem.

## Escopo preservado

Mapa, IA, detecção, áudio, transmissão de rede e layout do monitor vertical permanecem preservados.
