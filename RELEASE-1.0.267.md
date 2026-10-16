# Vigia IA 1.0.267+267

**Código-fonte corrigido após o workflow Android APK 221.** Não contém APK compilado.

- Corrigido `invalid_use_of_protected_member` dos quatro `setState` usados na extensão de diagnósticos da IA: as mudanças visuais são delegadas ao método da classe `State`.
- Não foram alterados os fluxos de vídeo, seleção do detector, relatório, duração do diagnóstico ou consulta de bateria e temperatura do Minha Câmera.
- `flutter analyze` e compilação devem ser confirmados no próximo workflow; testes de UI em aparelho pendentes.
