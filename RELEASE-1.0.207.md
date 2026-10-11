# Vigia IA 1.0.207+207

Diagnóstico ampliado para encerramentos ao abrir câmeras RTSP.

## Alterações

- Inclui opção de decodificação por software para testar incompatibilidades do driver H.264/H.265 (mais CPU/bateria).
- Registra etapa de abertura RTSP de forma persistente antes de iniciar o player.
- Inclui no relatório o último marco e motivo de saída informado pelo Android (Android 11+).
- Registra erros relatados pelo player e ao abrir a segunda câmera RTSP.
- Oculta usuário, senha, path e query RTSP em logs e diagnóstico.
- Impede inicializar VLC quando a porta da câmera não responde.
- Esclarece que porta aberta não significa vídeo reproduzível.

## Validação pendente

- Confirmar a estabilidade do player no aparelho físico.
- Inspecionar `adb logcat` em caso de crash nativo e identificar biblioteca/codec atingido.
- Rodar `flutter analyze`, `flutter test` e build APK no pipeline Flutter.
