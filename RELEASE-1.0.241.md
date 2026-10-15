# Vigia IA 1.0.241+241

## Correção de testes de telemetria após Android-APK-196

- As verificações de altitude e precisão do GPS agora consideram número e unidade juntos: `553 m` e `±8 m`.
- Um teste adicional confere essas leituras no painel compacto.
- Os indicadores, serviços, navegação, funcionamento offline e gravação permanecem inalterados.
- O verificador preventivo ganhou uma proteção para impedir expectativas de números sem unidade.

**Status:** pacote de código-fonte corrigido após o workflow Android-APK-196. A nova compilação Android e os testes Flutter completos ainda precisam ser executados no GitHub Actions.
