#!/usr/bin/env python3
"""Contratos de UX da 1.0.220. Não substitui testes Flutter no aparelho."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
read = lambda path: (root / path).read_text(encoding='utf-8')
key = read('lib/widgets/offline_map_manager_sheet.dart')
mapui = read('lib/screens/map_monitoring_screen.dart')
schedule = read('lib/services/bike_trip_schedule.dart')
tests = read('test/bike_trip_schedule_test.dart')
checks = {
    'stadia só revela a chave por solicitação explícita':
        key.count('await _service.revealStadiaApiKey()') == 2 and
        key.index('Future<void> _configureStadiaKey() async') < key.index('tooltip: \'Revelar chave\'')
        if 'tooltip: \'Revelar chave\'' in key else 'visibleSavedKey == null' in key,
    'remover a chave requer confirmação':
        'Remover chave Stadia Maps?' in key and 'confirmed != true' in key,
    'o gerenciador reduz quando não há pacotes':
        'heightFactor: hasPackages || service.busy || height < 740' in key and
        'Nenhum mapa offline baixado' in key,
    'almoço manual é respeitado no cálculo':
        'bool forceLunch = false' in schedule and 'forceLunch: _tripLunchExplicit' in mapui and
        'almoço manual é aplicado mesmo em trajetos curtos' in tests,
    'ajustes do plano não bloqueiam a lista de dias':
        'Ajustar pausas e refeições' in mapui and
        'ChoiceChip(label: const Text(\'Automático\')' in mapui,
    'prévia de rota pode ser recolhida':
        'bool _previewCollapsed = false;' in mapui and
        'onToggleCollapsed:' in mapui and 'Ver trajeto' in mapui and 'Salvar offline' in mapui,
    'configuração de camadas por grupos':
        "ValueKey('map-appearance-section')" in mapui and
        "ValueKey('map-provider-section')" in mapui and
        "ValueKey('map-base-section')" in mapui and
        'class _MapStyleThumbnailPainter' in mapui,
}
for label, passed in checks.items():
    if not passed:
        raise SystemExit(f'UX 1.0.220: FALHA: {label}')
print('Contratos da interface 1.0.220: OK')
