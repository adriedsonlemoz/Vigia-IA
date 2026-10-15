# Vigia IA 1.0.247+247

- Novo botão **Salvar esta câmera** no painel Minha Câmera após conexão bem-sucedida por QR/URL.
- Lista **Câmeras salvas** com reconexão sem novo QR e remoção individual confirmada.
- Nome editável; token de acesso não aparece na lista, cadastros mantidos no diretório privado do app (até 20).
- Não altera o transmissor nem os mecanismos MJPEG, IA local, MCRP ou mapas.
- Testes novos: `test/mcrp_saved_cameras_store_test.dart`, `test/mcrp_saved_cameras_screen_test.dart`.
- Sem Flutter SDK local: flutter analyze / flutter test / APK aguardam CI.
