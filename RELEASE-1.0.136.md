# Vigia IA 1.0.136+136

## Navegação guiada + recálculo automático

Esta versão reúne as duas próximas implantações previstas para o mapa.

- A rota ciclável agora inclui manobras e instruções em português retornadas pelo serviço de roteamento.
- O banner de navegação acompanha a instrução atual, próxima manobra, distância até a próxima ação, distância/tempo restantes e progresso percentual.
- O cálculo de orientação fica isolado em `MapNavigationGuidance`, sem acoplar geometria e regras de desvio à UI.
- Quando duas leituras consecutivas do GPS ficam fora da rota, o app recalcula a rota a partir da posição atual.
- Um cooldown de 45 segundos evita recálculos repetidos por ruído de GPS ou falha temporária de rede.
- Respostas antigas de rota são descartadas por serial de requisição, evitando que uma consulta atrasada substitua a rota vigente.
- Se o serviço online falhar, a direção direta permanece como fallback.
