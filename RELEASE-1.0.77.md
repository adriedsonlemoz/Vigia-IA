# Vigia IA 1.0.77+77

## Motivo da mudança

O diagnóstico da versão 1.0.75 mostrou falhas `FILE_UNAVAILABLE` na etapa `resolve_source`. Os slots `person_detected`, `person_exited` e `animal_exited` chegaram ao player com `resource_id_zero`, apesar de os M4A existirem no projeto.

## O que mudou

- Os 78 áudios integrados agora são ligados a constantes `R.raw` em `AudioResourceCatalog`.
- A busca por reflexão e `Resources.getIdentifier` foi removida.
- `AlertAudioPlayer` recebe o catálogo compilado e resolve o ID sem depender do nome do pacote em tempo de execução.
- O diagnóstico diferencia slot não mapeado de ID inválido e publica a cobertura dos recursos integrados.
- O bootstrap inclui o novo catálogo ao recriar o Android.
- Uma verificação automática compara catálogo Dart, catálogo Kotlin e arquivos M4A.

## Validação recomendada no aparelho

1. Instale o APK 1.0.77+77 sobre a versão anterior.
2. Em Configurações > Áudios e voz, teste pessoa detectada, pessoa saiu e animal saiu.
3. Confirme reprodução do M4A sem fallback TTS.
4. Exporte o diagnóstico e confirme `bundledResourceCount: 78`, `bundledMissingSlots: []` e `lastResource` diferente de zero.
5. Repita um alerta real no Monitor e confira que a etapa `resolve_source` não registra `FILE_UNAVAILABLE`.
