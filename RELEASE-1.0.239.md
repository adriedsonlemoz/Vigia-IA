# Vigia IA 1.0.239+239

## Correção de compatibilidade no CI

- Resolvidas as dez ocorrências de `use_key_in_widget_constructors` identificadas em sete bibliotecas de widgets do mapa no workflow **Vigia IA Android APK 194**.
- `super.key` nomeado foi incluído nos construtores dos dez widgets públicos envolvidos, sem alterar estado, aparência, ações ou serviços.
- Acrescentada verificação preventiva para impedir que a ausência de `key` reapareça nas próximas extrações.
- Preservados o armazenamento de mapas, GPS, gravação GPX, rotas offline, câmeras, IA e ESP32.

**Status:** código-fonte corrigido. Flutter Analyze, Flutter Test e geração do APK precisam ser reexecutados no GitHub Actions; o build 194 foi interrompido antes desses testes.
