# Vigia IA 1.0.199+199

Integração opcional do Google Maps no módulo de mapas, preservando o renderer atual e suas funções existentes.

## Mapa

- O `FlutterMap` atual continua sendo o provedor padrão e não foi removido.
- O usuário pode selecionar `Google Maps` em **Aparência e camadas > Provedor do mapa**.
- Google oferece modos Normal, Satélite/Híbrido e Terreno por meio do `google_maps_flutter`.
- Pontos do Vigia, destino, início/fim, posição atual e rotas continuam sendo alimentados pelos mesmos modelos e serviços existentes.
- O modo offline/MBTiles continua pertencendo ao mapa atual e não depende do Google.
- A chave Android é lida de `MAPS_API_KEY` em `android/local.properties`, sem gravá-la no código-fonte.

## Compatibilidade

- A preferência do provedor é persistida e versões anteriores continuam abrindo no `Mapa atual`.
- A implementação mantém o sistema de navegação, GPS, busca, POIs, rádio, câmeras e demais módulos fora do renderer.

## Validação

- `python3 tool/check_version_sync.py`
- `bash tool/verify_project.sh`
- `flutter analyze`
- `flutter test`
- Workflow Android de release

A chave do Google Maps e o billing da conta Google Cloud são responsabilidades da configuração do desenvolvedor. A documentação oficial exige API key e billing habilitado para o Google Maps for Flutter.
