# Vigia IA 1.0.246+246

- Corrige o lint `curly_braces_in_flow_control_structures` em `lib/screens/mcrp_camera_screen.dart:437:56`, apontado pelo workflow Android-APK-201 durante `flutter analyze --fatal-infos --fatal-warnings`.
- A condição que protege a inferência continua idêntica: sem IA habilitada, modelo pronto ou sessão vigente, não há análise de quadros. Somente `return;` foi inserido em um bloco `{ ... }`.
- Preservados QR Minha Câmera, MJPEG, painel MCRP, modo 1.4.35, controle remoto, prévia, overlay de IA e MediaStore.
- Adicionado verificador de regressão com cinco testes Python por mutação, sem desativar nenhuma regra do analyzer.
- Atualizados versionName/versionCode e todos os metadados/documentos da versão.
- Reexecutar `flutter analyze`, `flutter test` e build APK no CI; não há Flutter/Android SDK no ambiente local.
