# Vigia IA 1.0.206+206

Identificação de pessoas, veículos e animais no monitor.

## Alterações

- **Nome específico:** `ObjectFilterCatalog.displayNameForLabel`; `ObjectFilterPolicy` deixa de trocar o nome por Automóvel/Animal.
- **Mensagens de alerta:** padrão `{objeto} {detectado}.` com concordância; migração dos textos padrão antigos.
- **Possível pessoa:** `Detection.inferred`, rótulo próprio, confiança menor, `isStrong` falso e confirmação em 3 quadros (`PersonHintConfirmer`).
- **Testes:** `person_hint_confirmer_test.dart`, `inferred_detection_test.dart`, `object_filter_policy_test.dart` ampliado.

## Limitações conhecidas

- Os áudios gravados por slot continuam genéricos ("Automóvel detectado", "Animal detectado"); não há gravação por espécie. O nome específico aparece na notificação, no histórico, na tela e na voz sintética.
- O detector continua limitado às classes COCO (sem fauna brasileira) e sem tratamento específico para câmera infravermelha.
- Flutter/Kotlin e a rede não estavam disponíveis ao editar: `flutter analyze`, `flutter test` e o build precisam ser confirmados pelo workflow.
