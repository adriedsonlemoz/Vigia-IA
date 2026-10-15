#!/usr/bin/env python3
"""Contratos estaticos e comprovacao de transposicao dos widgets da 1.0.234.

Nao substitui `flutter analyze` nem `flutter test` em CI.
"""
from pathlib import Path
import hashlib
import re

root = Path(__file__).resolve().parents[1]
screen = (root / 'lib/screens/map_monitoring_screen.dart').read_text()
widget = (root / 'lib/widgets/map_telemetry_strip.dart').read_text()
tests = (root / 'test/map_telemetry_strip_test.dart').read_text()
block = widget[widget.index('class MapTelemetryStrip extends StatelessWidget {'):].strip()
expected_hash = 'dd760b9b584ab847e56d077aba68d02732aaf540f892c9a133d273bc44539f20'
checks = {
    'widget transposto sem mudar o corpo 1.0.233': hashlib.sha256(block.encode()).hexdigest() == expected_hash,
    'import integrado': "import '../widgets/map_telemetry_strip.dart';" in screen,
    'uso real do widget': len(re.findall(r'\bMapTelemetryStrip\s*\(', screen)) == 1,
    'classe em arquivo novo': 'class MapTelemetryStrip extends StatelessWidget {' in widget,
    'cartao privado dentro da biblioteca': 'class _MapTelemetryCard extends StatelessWidget {' in widget,
    'classes removidas da tela original': all(x not in screen for x in (
        'class _MapTelemetryStrip ', 'class MapTelemetryStrip ', 'class _MapTelemetryCard ',
    )),
    'dependencias so de politicas e modelos': all(s in widget for s in (
        "import '../models/map_weather.dart';",
        "import '../services/map_view_policy.dart';",
        "import '../services/map_weather_policy.dart';",
    )),
    'sem dependencias da tela ou serviços singleton': all(s not in widget for s in (
        'map_monitoring_screen.dart', 'MapWeatherService.instance', 'MapRouteService.instance',
        'MapConnectivityService.instance', 'MapCompassService(',
    )),
    'sem ciclo de vida proprio': all(s not in widget for s in (
        'initState(', 'dispose(', 'addListener(', 'Timer(', 'StreamSubscription',
    )),
    'cinco cartoes visuais': block.count('child: _MapTelemetryCard(') == 5,
    'cinco callbacks preservados': all(f'onTap: {callback},' in block for callback in (
        'onSpeedTap','onAltitudeTap','onCompassTap','onGpsTap','onWeatherTap',
    )),
    'sinaliza GPS antigo': 'GPS antigo' in block and 'gpsHasFix && !gpsIsFresh' in block,
    'sinaliza clima antigo': 'Clima antigo' in block and 'MapWeatherPolicy.currentValue' in block,
    'teste widget Flutter presente': 'testWidgets(' in tests and tests.count('testWidgets(') >= 5,
    'base widget anterior preservada': (root / 'lib/widgets/map_status_indicators.dart').is_file()
       and (root / 'lib/widgets/map_zoom_controls.dart').is_file(),
    'part offline preservada': "part 'map_monitoring_offline_support.dart';" in screen,
}
for label, ok in checks.items():
    if not ok:
        raise SystemExit('ERRO de refatoracao 1.0.234: '+label)
print(f'Refatoracao 1.0.234: {len(checks)} contratos OK')
