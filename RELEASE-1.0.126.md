# Vigia IA 1.0.126+126

## Foco

Esta versão fortalece a base de GPS e percurso antes das próximas evoluções visuais do mapa. A posição passa por validação e suavização antes de alimentar a UI, e **gravar por onde passei** deixa de ser confundido com **navegar até um destino**.

## Principais mudanças

- GPS rejeita precisão acima de 60 m, coordenadas inválidas, leituras fora de ordem, velocidades acima de 70 m/s e deslocamentos fisicamente incompatíveis.
- Percurso é mais rigoroso: somente pontos com precisão de até 35 m podem entrar na gravação.
- Jitter de GPS é reduzido por suavização adaptativa e limiar de movimento baseado na incerteza das leituras.
- Heading recebe interpolação circular e pode usar o deslocamento aceito como fallback quando há movimento suficiente.
- Ações do percurso passam a se chamar **Gravar**, **Pausar/Continuar** e **Encerrar percurso**.
- POIs ganham **Navegar até**, criando destino persistente independente da gravação e mostrando distância/rumo direto.
- Persistência sobe para schema 3 com migração do estado anterior.
- Corrigidos fim do percurso usando posição não gravada e tempo artificial após recriação do processo.

## Compatibilidade

- O campo legado `tracking` continua sendo gravado/lido durante a migração.
- Métodos antigos `startRoute`, `pauseRoute`, `resumeRoute` e `finishRoute` continuam disponíveis como wrappers.
- RouteExplorer, mapas offline, alertas, GPX e integrações existentes permanecem preservados.

## Validação

- `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh` devem passar antes do empacotamento.
- O ambiente desta entrega não possui Flutter/Dart SDK; `flutter analyze`, `flutter test` e build Android precisam ser confirmados no workflow com SDK.
