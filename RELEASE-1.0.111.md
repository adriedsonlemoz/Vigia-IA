# Vigia IA 1.0.111+111

## Resumo

A versão 1.0.111 transforma o botão **Mapa** em um painel **Mapa e percurso**, adicionando busca por locais úteis no raio escolhido, lista offline e alertas de aproximação por fala/notificação.

## Entregas principais

- painel **Mapa e percurso** acessível a partir do botão **Mapa** do monitor;
- exploração por raio com categorias de pontos úteis;
- busca online via OpenStreetMap/Overpass;
- fallback para lista offline salva localmente;
- alertas automáticos de aproximação com fala e/ou notificação;
- documentação e verificadores sincronizados para `1.0.111+111`.

## Observações de validação

- `python3 tool/check_version_sync.py`
- `bash tool/verify_project.sh`
- Flutter/Android SDK não estão instalados neste ambiente, então `flutter analyze`, `flutter test` e o APK final ainda dependem do workflow/CI.

## Versão

- `1.0.111+111`
