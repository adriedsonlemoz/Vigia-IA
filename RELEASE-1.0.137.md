# Vigia IA 1.0.137+137

## Rotas alternativas para bicicleta

- O pedido de rota passa a solicitar até duas alternativas adicionais, além da rota principal.
- Quando o servidor retorna opções distintas, todas aparecem no mapa; a rota ativa fica visualmente destacada.
- O banner mostra qual opção está selecionada e permite abrir uma lista com distância e duração de cada rota.
- A troca de alternativa atualiza imediatamente manobras, progresso restante e detecção de saída da rota.
- O recálculo automático da 1.0.136 permanece ativo e passa a obter novamente as alternativas a partir da posição atual.
- Alternativas duplicadas são descartadas para não apresentar escolhas visualmente equivalentes.
- Se não houver alternativa disponível, a experiência permanece exatamente como antes, com uma única rota; se o serviço falhar, direção direta continua como fallback.
