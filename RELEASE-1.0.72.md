# Vigia IA 1.0.72+72

Data: 2026-09-21.

## Correção aplicada

- Corrigido o `flutter analyze` do Android-APK-40.
- Removido o operador nulo desnecessário em `remote_camera_server_service.dart`.
- Removido o import redundante em `remote_phone_camera_source_test.dart`.
- Mantidas as melhorias da 1.0.71 para recepção remota, faixa de status dos aparelhos e áudio integrado.

## Decisão sobre o mini mapa/GPS

O mini mapa/GPS deve ficar no aparelho receptor, ou seja, no celular usado para ver a transmissão.

O celular transmissor deve continuar exclusivo para capturar e enviar imagem. Se o mapa for implementado depois, o transmissor pode enviar apenas dados leves de localização/status junto ao `/status`, sem desenhar mapa nele e sem misturar a cadência do GPS com a cadência dos quadros da câmera.

## Como validar no workflow

1. Executar o Android-APK novamente.
2. Confirmar que `flutter analyze` não aponta `invalid_null_aware_operator` em `remote_camera_server_service.dart`.
3. Confirmar que `flutter analyze` não aponta `unnecessary_import` em `remote_phone_camera_source_test.dart`.
4. Confirmar que os testes da câmera remota continuam passando.
