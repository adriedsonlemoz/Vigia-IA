#!/usr/bin/env python3
"""Contract checks, not a substitute for Flutter analyze/test or hardware tests."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
read = lambda path: (ROOT / path).read_text(encoding='utf-8')

model = read('lib/models/bike_sensor_snapshot.dart')
service = read('lib/services/bike_sensor_service.dart')
safety = read('lib/services/bike_pressure_safety_service.dart')
hud = read('lib/widgets/bike_ride_hud.dart')
radio = read('lib/widgets/map_radio_panel.dart')
map_screen = read('lib/screens/map_monitoring_screen.dart')
wizard = read('lib/screens/esp32_setup_wizard.dart')
checks = {
    'limites independentes no modelo': 'effectiveFrontMinimumPsi' in model and 'effectiveRearMinimumPsi' in model,
    'critico dianteiro independente': 'frontTirePsi <= frontCriticalTirePressurePsi' in model,
    'critico traseiro independente': 'rearTirePsi <= rearCriticalTirePressurePsi' in model,
    'limites no diagnostico': "'rearMinimumTirePressurePsi': effectiveRearMinimumPsi" in model,
    'consolidacao origem dianteira': 'frontMinimumTirePressurePsi: frontPressure?.effectiveFrontMinimumPsi' in service,
    'consolidacao origem traseira': 'rearMinimumTirePressurePsi: rearPressure?.effectiveRearMinimumPsi' in service,
    'limites mantidos na desconexao': service.count('frontMinimumTirePressurePsi: current.frontMinimumTirePressurePsi') == 2,
    'perda rapida dianteira': 'minimumSafePsi: snapshot.effectiveFrontMinimumPsi' in safety,
    'perda rapida traseira': 'minimumSafePsi: snapshot.effectiveRearMinimumPsi' in safety,
    'HUD usa limites individuais': 'snapshot.frontTirePsi < snapshot.effectiveFrontMinimumPsi' in hud and 'snapshot.rearTirePsi < snapshot.effectiveRearMinimumPsi' in hud,
    'HUD omite leitura inexistente': 'snapshot.connected && snapshot.frontTirePressureAvailable ?' in hud,
    'ficha usa limites distintos': 'minimumPsi: snapshot?.effectiveFrontMinimumPsi' in map_screen and 'minimumPsi: snapshot?.effectiveRearMinimumPsi' in map_screen,
    'wizard sem recomendacao universal': 'não universal' in wizard,
    'radio evita polling simultaneo': 'if (_statusRequestInFlight) return;' in radio and '_statusRequestInFlight = false;' in radio,
    'radio valida URL que realmente toca': 'status.url == url && url.isNotEmpty' in radio,
    'regressoes Dart': (ROOT / 'test/bike_sensor_multi_module_limits_test.dart').exists(),
}
for name, ok in checks.items():
    if not ok:
        raise SystemExit(f'FAIL: {name}')
print(f'OK: {len(checks)} contratos Bike/ESP32/radio 1.0.230')
