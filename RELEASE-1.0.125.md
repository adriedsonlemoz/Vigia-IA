# Vigia IA 1.0.125+125

## Mapa em tela cheia

A versão 1.0.125 transforma o mapa em uma tela principal de viagem e monitoramento, reduzindo chrome fixo e integrando GPS, percurso, pontos úteis, câmeras e operação offline.

- O mapa ocupa praticamente 100% do viewport e não usa mais AppBar fixa.
- Controles flutuantes mantêm Voltar, zoom, seguir GPS, Próximos pontos, câmeras, offline e configurações sempre acessíveis.
- Em paisagem curta, os controles mudam de coluna para faixa horizontal.
- O acompanhamento padrão usa zoom 15 para exibir mais contexto ao redor da bike.
- Uma ou duas câmeras continuam arrastáveis e iniciam fora da área dos controles.

## Próximos pontos

- Resultados do `RouteExplorerService` agora aparecem como marcadores no mapa completo.
- A lista no próprio mapa mantém filtros Todos/Postos/Comida/Saúde/Água/Outros, atualização e salvamento offline.
- O toque em um ponto na lista do Monitor abre o mapa já centralizado no destino escolhido.
- O limite de resultados sobe de 12 para 36.
- Durante uma rota ativa em modo **No caminho**, a busca é renovada a cada 1,5 km ou 5 minutos, com fallback para dados offline.

## GPS e percurso

- A barra de rota fica compacta, com iniciar/encerrar, pausar/continuar e exportar GPX.
- Saltos de GPS maiores que 250 m criam um novo segmento: não viram reta no mapa e não entram na distância registrada.
- Rota, posição e estado continuam compartilhados entre Monitor e mapa completo.

## Compatibilidade

Não há migração de dados. Pacotes MBTiles, chave/configuração Stadia, lista offline de pontos, rota persistida e fontes de câmera existentes continuam compatíveis.

## Validação

`tool/check_version_sync.py` e `tool/verify_project.sh` devem passar antes da entrega. O ambiente de empacotamento atual não inclui Flutter/Android SDK, então `flutter analyze`, `flutter test` e APK permanecem para confirmação no workflow Android.
