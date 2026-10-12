# Vigia IA — Release 1.0.230+230

Data: 12/10/2026 · versionCode 230 · terceira de quatro versões planejadas

## Mudanças

- Bike: pressão dianteira e traseira conservam o limite do módulo ESP32 que gerou a leitura, evitando avisos falsos com vários dispositivos.
- A condição geral, o alerta de perda rápida e a ficha de pneus respeitam limites individuais; sensores ausentes não produzem zeros de leitura.
- Assistente ESP32 orienta configurar pressão segundo o próprio pneu/fabricante; 30 PSI não é faixa segura universal.
- Rádio: evita sobreposição do status nativo em chamadas concorrentes e corrige registro de saúde da URL tocando; favoritos, pesquisa, timer e minimização continuam disponíveis.
- Clima, câmera, IA, navegação e gravação preservados; sensores e ESP32 permanecem opcionais.

## Validações e limites

- Inclusos contratos Python e testes Dart de limites individuais e disponibilidade dos sensores.
- `flutter analyze`, `flutter test`, Gradle/APK e validação com módulos ESP32 reais não foram executados localmente. Requer CI e hardware de teste.
- Próxima 1.0.231: offline/autonomia e validação manual acumulada antes da refatoração gradual.
