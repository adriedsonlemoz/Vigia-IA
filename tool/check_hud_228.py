#!/usr/bin/env python3
"""Contratos estruturais auxiliares, não substituem flutter analyze/test."""
from pathlib import Path
r = Path(__file__).resolve().parents[1]
policy = (r/'lib/services/map_hud_presentation.dart').read_text()
widget = (r/'lib/widgets/map_hud_context_pill.dart').read_text()
screen = (r/'lib/screens/map_monitoring_screen.dart').read_text()
required = [
    ('política contextual', 'MapHudPresentationPolicy.resolve', screen),
    ('gravação ortogonal', 'recording: _routeState.recording', screen),
    ('simulador não ativa pedalada automática', "speedReading?.source == 'Simulação'", screen),
    ('pill contextual', 'MapHudContextPill(', screen),
    ('toggle dos instrumentos', '_hudExpandedOverride = !hud.showTelemetry', screen),
    ('painel secundário opcional', 'hud.showNearbyBanner', screen),
    ('atalho da Bike contextual', 'hud.showBikeShortcut', screen),
    ('câmera preservada em configurações', "title: const Text('Câmeras sobre o mapa')", screen),
    ('Bike preservada em configurações', "title: const Text('Bike e sensores')", screen),
    ('áudio preservado em configurações', "title: const Text('Áudio do mapa')", screen),
    ('rádio preservada em configurações', "title: const Text('Rádio online')", screen),
    ('gravação ativa no modo navegação', 'MapHudContext.navigating', policy),
    ('REC visual explícito', "const Text(' REC'", widget),
    ('widget test responsivo', 'TextScaler.linear(scale)', (r/'test/map_hud_context_pill_test.dart').read_text()),
]
for name, pattern, content in required:
    if pattern not in content:
        raise SystemExit(f'FALHA HUD: {name}')
print(f'HUD 1.0.228: {len(required)} contratos estruturais aprovados')
