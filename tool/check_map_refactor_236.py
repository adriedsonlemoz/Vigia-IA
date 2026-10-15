#!/usr/bin/env python3
"""Regressao de integracao e transposicao da tela do mapa, etapa 1.0.236."""
from pathlib import Path
import hashlib
import re

root = Path(__file__).resolve().parents[1]
screen = (root / 'lib/screens/map_monitoring_screen.dart').read_text()
widget = (root / 'lib/widgets/map_route_alternatives_button.dart').read_text()
tests = (root / 'test/map_route_alternatives_button_test.dart').read_text()
source = widget[widget.index('class MapRouteAlternativesButton extends StatelessWidget {'):].strip()
checks = {
  'SHA-256 do widget transposto': hashlib.sha256(source.replace('    super.key,\n', '').encode()).hexdigest() == '6f52155e3ed30aaf39943c4f9e8fefc98930a57449cd4b83fb4646c30b207fb3',
  'classe externa definida': 'class MapRouteAlternativesButton extends StatelessWidget {' in widget,
  'constructor e UI com mesmas opcoes': 'const MapRouteAlternativesButton({' in widget and 'PopupMenuButton<int>(' in widget,
  'integracao na tela uma vez': len(re.findall(r'\bMapRouteAlternativesButton\s*\(', screen)) == 1,
  'import local presente': "import '../widgets/map_route_alternatives_button.dart';" in screen,
  'classe privada antiga ausente': 'class _RouteAlternativesButton' not in screen,
  'nenhuma dependencia circular': 'map_monitoring_screen.dart' not in widget and 'part of' not in widget,
  'sem estado, streams ou timer': all(v not in widget for v in ('extends StatefulWidget', 'initState(', 'dispose(', 'StreamSubscription', 'Timer(', 'addListener(')),
  'nao modifica selecao': 'onSelected: onSelected' in widget and 'onSelected: onRouteSelected' in screen,
  'sem menu para apenas uma rota': 'final enabled = routes.length > 1;' in widget and 'enabled: enabled' in widget,
  'alternativas por indices': 'for (var index = 0; index < routes.length; index++)' in widget and 'value: index' in widget,
  'resumo da alternativa': 'distanceLabel(routes[index].distanceMeters)' in widget and 'durationLabel(routes[index])' in widget,
  'comparacao ausente informada': "'Sem comparação disponível'" in widget,
  'ponto original mantido': 'if (routeAlternatives.length > 1)' in screen and 'routeAlternatives: _cyclingRouteAlternatives' in screen,
  'testes Flutter adicionados': tests.count('testWidgets(') >= 5,
  'checks legados seguem ativos': all(s in (root / 'tool/verify_project.sh').read_text() for s in ('check_map_refactor_233.py', 'check_map_refactor_234.py', 'check_map_refactor_235.py', 'check_map_refactor_236.py')),
  'checagem mapa/rádio reativada': 'python3 tool/check_map_radio_219.py' in (root / 'tool/verify_project.sh').read_text(),
}
for desc, ok in checks.items():
    if not ok:
        raise SystemExit('ERRO refatoracao 236: ' + desc)
print(f'Alternativas de navegacao 236: {len(checks)} contratos OK')
