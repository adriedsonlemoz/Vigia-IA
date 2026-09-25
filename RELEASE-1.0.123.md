# Vigia IA 1.0.123+123

## Escopo

Esta entrega amplia o módulo ESP32 com um subsistema de energia independente, antes da reformulação do mapa.

## Mudanças

- Nova capacidade **Energia**, separada da bateria/alimentação do próprio ESP32.
- O ESP32 pode ser cadastrado para funcionar por power bank USB, tomada/fonte USB, bateria do sistema ou outra alimentação.
- Testes sem bateria física são suportados: **Sem bateria monitorada** é um estado válido do wizard.
- Bateria principal pode ser configurada como chumbo-ácido, LiFePO₄ ou outra química, com tensão nominal, capacidade em Ah e níveis de aviso/crítico.
- Preparados monitores por firmware, divisor de tensão, INA219, INA226 e BMS com telemetria.
- Entrada solar pode ser habilitada para telemetria de tensão, corrente e potência do painel/controlador.
- `/config` recebe bloco opcional `energy`; firmware legado continua compatível.
- Telemetria estruturada aceita bateria principal, corrente, potência, temperatura, energia acumulada, alimentação do módulo, modelo do monitor e dados solares.
- O card ESP32 diferencia bateria do módulo e bateria principal para evitar leituras/alertas trocados.
- Diagnóstico passa a carregar configuração e runtime de energia.

## Observação de hardware

O app fica preparado para o contrato de energia, mas este pacote não contém firmware do ESP32. A medição de 12 V nunca deve ser ligada diretamente a um GPIO/ADC sem interface elétrica adequada. INA219/INA226, divisor resistivo e BMS exigem dimensionamento e ligação compatíveis com a instalação real.

## Validação local

- `python3 tool/check_version_sync.py`
- `bash tool/verify_project.sh`
- Integridade do ZIP final

O ambiente desta entrega não possui Flutter/Android SDK. `flutter analyze`, `flutter test` e o build APK devem ser reconfirmados pelo workflow.
