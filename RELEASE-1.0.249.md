# Vigia IA 1.0.249+249

- Elimina I/O real do `testWidgets` de câmeras salvas, origem do travamento de 10 min no workflow Android-APK-204.
- Preserva a verificação de arquivos privados e JSON nos testes unitários independentes.
- Workflows falham mais cedo se um teste ficar pendente: limite de 2 min por teste, limite global de 7 min no step. Não remove testes nem cobertura.
- `flutter analyze` passou no workflow 204 para a 1.0.248; novo build Flutter/Android ainda não executado para a 1.0.249.
- Câmeras unificadas, QR, IA local, MJPEG, MCRP, mapas, sensores e navegação preservados.
