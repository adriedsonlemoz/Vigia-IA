# Relatório técnico • Vigia IA 1.0.242+242 / Minha Câmera 1.4.35

## Protocolo confirmado pelo código Kotlin 1.4.35

- QR em `PhoneCameraActivity.kt`: `BarcodeEncoder().encodeBitmap(live, BarcodeFormat.QR_CODE, ...)`.
- URL em `PhoneCameraServer.kt`: `http://<IPv4>:8765/live/<32 lowercase hex>` com chave aleatória por sessão.
- Streaming: resposta HTTP 200 `Content-Type: multipart/x-mixed-replace; boundary=frame`; corpo com cabeçalhos `Content-Type: image/jpeg`, `Content-Length`, metadados de bateria e JPEG binário.
- Estado do servidor: `GET /control/<token>/status` retorna headers; 409 na rota /live quando codec ativo é H.264.
- O QR do Minha Câmera não é o QR `vigiaia://pair` do Vigia IA e não possui `/frame.jpg`.

## Integração entregue

- Validador IPv4 privado `lib/services/minha_camera_live_url.dart` com port e token restritos; extensão de `RemoteCameraPairingService.decode` para ambos os formatos de QR.
- Receptor stream MJPEG `lib/sources/minha_camera_mjpeg_source.dart` e parser incremental bounded `lib/services/minha_camera_mjpeg_parser.dart`, usando `compute` na conversão JPEG-RGB quando IA ativa.
- Seleção única das fontes remotas pela factory `lib/sources/remote_phone_source_factory.dart`; rota Vigia antiga funciona sem mudança. Main e Secondary continuam separados, IA apenas para a principal.
- Modo Monitor oferece análise desligada (`analysisEnabled:false`) para apenas vídeo e `analysisEnabled:true` para enviar quadros ao detector LiteRT/TFLite já instalado. A seleção é persistida em `VideoSourceConfig` e os tokens são omitidos em exportações não sensíveis.
- Central multicâmera verifica status do Minha Câmera pelo endpoint correto, sem requisições de controle que mudem o transmissor.

## Restrições e testes

- A câmera transmissora deve usar MJPEG, com ambos os aparelhos no mesmo Wi-Fi/hotspot. MJPEG não equivale a H.264 e não há transcodificação implementada nesta entrega.
- QR/token devem ser tratados como credenciais; não compartilhar ou publicar. A senha de sessão muda quando a transmissão é reiniciada no Minha Câmera.
- Validação preventiva do projeto, tests Python históricos e contratos específicos executados localmente. Testes Dart/Flutter escritos, ainda não executados por ausência de Flutter SDK; CI e teste Android de rede real continuam obrigatórios.
- Não há inferência no Redmi A3, nem alteração do aplicativo Minha Câmera. O Vigia mantém sua IA, modelos, alertas e controle de sessão existentes.
