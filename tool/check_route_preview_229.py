#!/usr/bin/env python3
"""Verificações textuais auxiliares: NÃO substituem flutter analyze/test."""
from pathlib import Path
r=Path(__file__).resolve().parents[1]
screen=(r/'lib/screens/map_monitoring_screen.dart').read_text(encoding='utf-8')
metrics=(r/'lib/services/map_route_preview_metrics.dart').read_text(encoding='utf-8')
planner=(r/'lib/services/bike_trip_planner.dart').read_text(encoding='utf-8')
tests=(r/'test/map_route_preview_metrics_test.dart').read_text(encoding='utf-8')
proximity=(r/'test/bike_trip_route_proximity_test.dart').read_text(encoding='utf-8')
checks={
 'prévia não inicia navegação automaticamente': 'Future<void> _startPreviewNavigation() async' in screen and 'onStart: _startPreviewNavigation' in screen,
 'edição voluntária do ritmo': 'onEditPace: () => unawaited(_editPreviewBikePace())' in screen,
 'preferência guardada na prévia': 'bikePreferences: _effectiveBikeTravelPreferences' in screen,
 'sem ritmo fixo de 15 km/h na prévia': 'final speed = plan?.estimate.preferences.averageSpeedKmh ?? 15.0' not in screen,
 'comparação declarando limites': 'Relevo, qualidade e tipo de via: sem dados comparáveis' in screen,
 'tempo de bicicleta configurado': 'bikePreferences.averageSpeedKmh' in metrics,
 'tempo ausente não inventado': 'tempo indisponível' in metrics,
 'proximidade projetada no segmento': 'final squared = dx * dx + dy * dy;' in planner,
 'sem status de acesso por estrada': 'acesso por vias e serviços não verificados' in screen,
 'cobertura de ETA': 'ritmo salvo' in tests,
 'cobertura de parada em segmento longo': 'Trecho longo sem vértice no meio' in proximity,
}
for name, ok in checks.items():
    if not ok: raise SystemExit(f'FALHA 229: {name}')
print(f'Rotas 1.0.229: {len(checks)} contratos estruturais aprovados')
