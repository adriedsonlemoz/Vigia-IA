# ESP32 — contrato opcional de energia

A partir da 1.0.123, o Vigia IA diferencia a alimentação do próprio ESP32 da bateria principal que ele pode monitorar.

## Configuração enviada pelo app

O bloco `energy` de `/api/v1/config` ou `/config` é opcional. Exemplo conceitual:

```json
{
  "energy": {
    "enabled": true,
    "moduleSupply": "usbPowerBank",
    "monitor": "ina226",
    "battery": {
      "enabled": true,
      "chemistry": "leadAcid",
      "nominalVoltageV": 12.0,
      "capacityAh": 7.0,
      "warningPercent": 25,
      "criticalPercent": 10
    },
    "solar": { "enabled": true }
  }
}
```

`battery.enabled` pode ser `false`; isso representa bancada/power bank/tomada sem bateria principal conectada.

## Telemetria recomendada

```json
{
  "moduleId": "energy-pack",
  "capabilities": ["energy"],
  "power": {
    "source": "usbPowerBank",
    "monitor": { "model": "INA226" },
    "battery": {
      "present": true,
      "chemistry": "leadAcid",
      "percent": 74,
      "voltageV": 12.62,
      "currentA": -1.35,
      "powerW": -17.0,
      "temperatureC": 28.4
    },
    "solar": {
      "voltageV": 18.2,
      "currentA": 0.42,
      "powerW": 7.64
    },
    "energyInWh": 32.1,
    "energyOutWh": 18.4
  }
}
```

A bateria do próprio módulo continua usando os campos legados/top-level (`batteryPercent`, `batteryVoltage`) ou equivalentes de `moduleBattery*`. Assim a bateria principal não é confundida com a alimentação do ESP32.

Convenção recomendada: `currentA`/`powerW` positivos quando a bateria está recebendo energia e negativos quando está fornecendo energia. O firmware também pode enviar `charging` explicitamente; o app não depende apenas do sinal para decidir esse estado.

## Instalação solar

O Vigia IA apenas monitora o sistema de energia; ele não substitui o controlador de carga. Em uma instalação com painel e bateria, a ligação de potência continua sendo feita por um controlador adequado à química da bateria. A telemetria solar pode vir do próprio controlador ou de um segundo canal/sensor de medição; um único INA219/INA226 não mede simultaneamente dois ramos elétricos independentes.

## Segurança elétrica

12 V de bateria não devem ser aplicados diretamente a um pino do ESP32. O firmware/hardware deve usar interface adequada (por exemplo INA219/INA226, divisor dimensionado/protegido ou BMS compatível) e compartilhar terra somente quando o projeto elétrico exigir e for seguro.

## Telemetria ambiental para o clima

A partir da 1.0.166, um módulo ESP32 pode fornecer medições ambientais reais para o mini-card de clima. O bloco pode ser enviado como `telemetry.environment`, `environment`, `telemetry.weather`, `weather` ou `sensors.ambient`.

Exemplo recomendado:

```json
{
  "moduleId": "ambiente-bike",
  "capabilities": ["ambient", "temperature"],
  "environment": {
    "temperatureC": 27.3,
    "humidityPercent": 64,
    "pressureHpa": 1008.7,
    "capturedAt": "2026-09-26T15:00:00Z"
  }
}
```

Campos aceitos quando realmente medidos:

- `temperatureC`: temperatura ambiente em graus Celsius;
- `humidityPercent` ou `relativeHumidityPercent`: umidade relativa em porcentagem;
- `pressureHpa`/`pressureHPa`/`pressureMb`: pressão já expressa em hPa/mbar;
- `pressurePa`: pressão explicitamente em pascal; o app converte para hPa;
- `capturedAt`: horário ISO-8601 da medição, quando o firmware possuir relógio confiável.

O app não interpreta um campo genérico `pressure` sem unidade e não cria condição de céu, chuva, vento ou previsão a partir apenas da temperatura. Dados ausentes permanecem indisponíveis e, quando houver internet, podem ser complementados pelo provedor meteorológico online com a origem mostrada separadamente.
