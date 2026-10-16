# Vigia IA 1.0.253+253 — Android APK 207 buildfix

- Origem: workflow 207 encerrou com código 1 na etapa Análise estática antes de gerar APK; 82 testes Python passaram.
- Causa: lint `curly_braces_in_flow_control_structures` no retorno antecipado da visibilidade do minimapa em `lib/screens/monitor_screen_fullscreen.dart:56:76`.
- Tratamento: apenas inserir `{ return; }` na mesma guarda, sem mudar lógica de visibilidade, ativação ou desativação do minimapa.
- `flutter analyze --fatal-infos --fatal-warnings` permanece obrigatório; teste preventivo verifica a guarda e impede supressão de lint.
- Todos os modos da Home, Ao vivo local, MCRP, câmeras cadastradas e GPS/mapa sob demanda preservados.
- Ainda não executado: `flutter analyze`, `flutter test` completo e build Android em CI.
