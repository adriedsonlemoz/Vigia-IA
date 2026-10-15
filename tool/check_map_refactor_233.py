#!/usr/bin/env python3
"""Contratos de extracao de widgets na 1.0.233; nao substituem testes Flutter."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
screen = (root/'lib/screens/map_monitoring_screen.dart').read_text()
status = (root/'lib/widgets/map_status_indicators.dart').read_text()
zoom = (root/'lib/widgets/map_zoom_controls.dart').read_text()
checks = {
    'import dos indicadores': "import '../widgets/map_status_indicators.dart';" in screen,
    'import dos controles de zoom': "import '../widgets/map_zoom_controls.dart';" in screen,
    'indicador instalado no mapa': 'MapSystemHud(' in screen,
    'pill de velocidade instalado no mapa': 'MapFocusSpeedPill(' in screen,
    'espacador instalado no mapa': 'MapControlGap(' in screen,
    'zoom instalado no mapa': 'MapZoomCluster(' in screen,
    'widget HUD em biblioteca isolada': 'class MapSystemHud extends StatelessWidget' in status,
    'widget velocidade em biblioteca isolada': 'class MapFocusSpeedPill extends StatelessWidget' in status,
    'callback velocidade mantido': 'onTap: onTap' in status,
    'widget zoom em biblioteca isolada': 'class MapZoomCluster extends StatelessWidget' in zoom,
    'botao interno privado': 'class _MapZoomAction extends StatelessWidget' in zoom,
    'callbacks de zoom mantidos': 'onPressed: onZoomIn' in zoom and 'onPressed: onZoomOut' in zoom,
    'tamanhos UX preservados': 'MapUxPolicy.controlSize' in zoom and 'MapUxPolicy.controlGap' in zoom,
    'sem widget duplicado': all(('class '+x) not in screen for x in ('MapSystemHud', 'MapFocusSpeedPill', 'MapControlGap', 'MapZoomCluster')),
    'sem scheduler ou listener novos': all(token not in status+zoom for token in ('Timer(', 'addListener(', 'StreamSubscription', 'initState(', 'dispose(')),
    'teste HUD presente': (root/'test/map_status_indicators_test.dart').is_file(),
    'teste zoom presente': (root/'test/map_zoom_controls_test.dart').is_file(),
    'part privado offline preservado': "part 'map_monitoring_offline_support.dart';" in screen,
}
for label, ok in checks.items():
    if not ok:
        raise SystemExit('FALHA refatoracao 1.0.233: '+label)
print(f'Refatoracao 1.0.233: {len(checks)} contratos OK')
