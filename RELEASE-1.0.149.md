# Vigia IA 1.0.149+149

## Consolidação mapa + Bike

Esta versão fecha a consolidação do bloco mapa + Bike antes da etapa planejada de navegação 3D. O foco é eliminar estados cruzados incoerentes sem recriar recursos que já existem.

### Principais ajustes

- Mini mapa automático permanece visível enquanto houver navegação ativa, inclusive em paradas temporárias.
- TTC/aproximação no PiP exige estado recente e câmera/IA válidos; dados antigos deixam de parecer atuais após falha, perda de conexão ou ausência de frames.
- Encerramento externo da navegação limpa também a rota local, alternativas, fallback, progresso e estado de recálculo do mapa.
- Fallback de POIs offline não seleciona pacote salvo muito distante da região atual apenas por ser o mais próximo disponível.
- Categorias de POI desativadas são removidas imediatamente das listas e marcadores, sem exigir nova consulta.
- Nova `MapBikeConsolidationPolicy` concentra essas regras de integração e recebeu testes de regressão.

## Compatibilidade

- Nome público: Vigia IA
- Nome técnico: vigiaia
- Package Android: `com.vigiaia.app`
- Versão: `1.0.149+149`

## Validação local

Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`. Flutter/Dart não estão disponíveis no ambiente de edição atual; `flutter analyze`, `flutter test` e o build Android devem ser confirmados pelo workflow.
