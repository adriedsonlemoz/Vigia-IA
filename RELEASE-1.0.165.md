# Vigia IA 1.0.165+165

## Escopo
Buildfix da ETAPA 2, sem antecipar Clima Inteligente ou qualquer etapa seguinte do mapa.

## Entrega
- Sanitizador do diagnóstico MapLibre 3D usa sintaxe `RegExp` aceita pelo Dart para busca case-insensitive.
- Redação de chaves, tokens e secrets permanece ativa; URLs continuam sem query/fragment no diagnóstico.
- Verificador preventivo passa a bloquear a reintrodução do modificador inline incompatível.
- Telemetria compacta/clicável da 1.0.164 e toda a navegação existente permanecem preservadas.
- Popup Novidades exclusiva da versão atual e sem detalhes técnicos de falha.

## Validação local
Executar `python3 tool/check_version_sync.py`, `bash -n tool/verify_project.sh` e `bash tool/verify_project.sh`. Flutter/Dart não estão disponíveis no ambiente local e devem ser confirmados no CI.
