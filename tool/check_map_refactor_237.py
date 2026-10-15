#!/usr/bin/env python3
"""Protege a transposicao dos widgets de metricas e POIs da navegacao (1.0.237)."""
from pathlib import Path
import hashlib
import re

root = Path(__file__).resolve().parents[1]
screen = (root / 'lib/screens/map_monitoring_screen.dart').read_text(encoding='utf-8')
widget = (root / 'lib/widgets/map_navigation_metrics.dart').read_text(encoding='utf-8')
tests = (root / 'test/map_navigation_metrics_test.dart').read_text(encoding='utf-8')
source = widget[widget.index('class MapNavigationMetricCell extends StatelessWidget {'):].strip()
checks = {
    'codigo dos dois widgets identico ao original (apos renomeacao)':
        hashlib.sha256(source.encode()).hexdigest() == '00b7ba379ae9356a4f31bb2b8496b3867dbb4361ffeb6ca3315b04fc0784a70a',
    'arquivo unico para metricas e chips':
        'class MapNavigationMetricCell extends StatelessWidget {' in widget and
        'class MapNavigationPoiChip extends StatelessWidget {' in widget,
    'import local integrado':
        screen.count("import '../widgets/map_navigation_metrics.dart';") == 1,
    'quatro metricas na mesma faixa':
        len(re.findall(r'\bMapNavigationMetricCell\s*\(', screen)) == 4,
    'quatro categorias de pontos mantidas':
        len(re.findall(r'\bMapNavigationPoiChip\s*\(', screen)) == 4 and
        all(f"label: '{label}'" in screen for label in ('Água', 'Comida', 'Descanso', 'Parada')),
    'metricas mostram progresso existente':
        "'${(progressFraction * 100).round()}%'" in screen,
    'distancias calculadas continuam na tela':
        '_distance(water.distanceMeters)' in screen and
        '_distance(food.distanceMeters)' in screen and
        '_distance(rest.distanceMeters)' in screen and
        '_distance(stop.distanceMeters)' in screen,
    'placeholder para ponto indisponivel preservado':
        all(f'{name} == null ? \'--\'' in screen for name in ('water', 'food', 'rest', 'stop')),
    'sem duplicacao de classes privadas':
        'class _NavigationMetricCell' not in screen and
        'class _NavigationPoiChip' not in screen,
    'sem dependencia circular ou part':
        'map_monitoring_screen.dart' not in widget and 'part of' not in widget,
    'sem timers ou estado adicional':
        all(v not in widget for v in (
            'StatefulWidget', 'initState(', 'dispose(', 'StreamSubscription', 'Timer(',
            'addListener(', 'setState(', 'HttpClient', 'Geolocator')),
    'tipografia compacta/expandida preservada':
        'compact ? 12 : 14' in widget and 'compact ? 9 : 10.5' in widget,
    'testes Flutter escritos':
        tests.count('testWidgets(') >= 7,
    'legado do painel ainda inspeciona novos componentes':
        "grep -q 'class MapNavigationMetricCell extends StatelessWidget' lib/widgets/map_navigation_metrics.dart" in
        (root / 'tool/verify_project.sh').read_text(encoding='utf-8') and
        "grep -q 'class MapNavigationPoiChip extends StatelessWidget' lib/widgets/map_navigation_metrics.dart" in
        (root / 'tool/verify_project.sh').read_text(encoding='utf-8'),
    'contratos anteriores ainda incluidos':
        all(f'python3 tool/check_map_refactor_{v}.py' in
            (root / 'tool/verify_project.sh').read_text(encoding='utf-8')
            for v in (233, 234, 235, 236)),
}
for name, passed in checks.items():
    if not passed:
        raise SystemExit('ERRO refatoração 237: ' + name)
print(f'Navegação modular 237: {len(checks)} contratos OK')
