# Vigia IA 1.0.129+129

## Mapa: camadas e tipos

- Adiciona Padrão, Bike/Viagem, Terreno, Topográfico e Satélite.
- OSM segue como opção gratuita; Bike/Viagem pode usar Stadia Outdoors, Topográfico usa OpenTopoMap e Terreno/Satélite reutilizam a chave Stadia configurável já existente.
- Reorganiza os controles permanentes e concentra ações secundárias em Opções.

## Próximos pontos e offline

- POI tocado fica selecionado e recebe card compacto com distância, categoria, origem, detalhes e Navegar até.
- O cache offline deixa de ser uma lista única e passa a aceitar vários pacotes regionais com nome, bounds, raio, data e quantidade de locais.
- Dados antigos migram para “Lista offline antiga”.
- Atualização automática passa a funcionar durante deslocamento mesmo sem gravar percurso e considera distância, tempo, heading e borda da área.

## Validação

- Validadores internos e sincronização de versão devem ser executados antes do ZIP final.
- Flutter analyze/test e build Android exigem Flutter/Android SDK disponível.
- APK/AAB permanece fora do ZIP-fonte.
