#!/usr/bin/env python3
"""Contratos estaticos de integracao 1.0.235, sem substituir Flutter/Android."""
from pathlib import Path
import hashlib,re
root=Path(__file__).resolve().parents[1]
screen=(root/'lib/screens/map_monitoring_screen.dart').read_text()
widget=(root/'lib/widgets/map_route_preview_card.dart').read_text()
test=(root/'test/map_route_preview_card_test.dart').read_text()
block=widget[widget.index('class MapRoutePreviewCard extends StatelessWidget {'):].strip()
checks={
 'codigo transposto preservado SHA256': hashlib.sha256(block.replace('    super.key,\n', '').encode()).hexdigest() == 'fecf1504102b648af43af5712f4aeb5445907e4fc18da010045f9fd89c9cb9c2',
 'chamada unica no mapa': len(re.findall(r'\bMapRoutePreviewCard\s*\(',screen)) == 1,
 'classe publica e import': 'class MapRoutePreviewCard extends StatelessWidget {' in widget and "import '../widgets/map_route_preview_card.dart';" in screen,
 'classe antiga removida': 'class _RoutePreviewCard' not in screen,
 'sem depender da tela': "map_monitoring_screen.dart" not in widget and "part of" not in widget,
 'sem estado e timers': all(x not in widget for x in ('extends StatefulWidget','initState(', 'dispose(', 'addListener(', 'Timer(', 'StreamSubscription')),
 'usa metricas ja existentes': 'MapRoutePreviewMetrics.forRoute(' in widget,
 'callbacks mantidos': all('onPressed: '+x in widget or 'onSelected: (_) => '+x+'(index)' in widget for x in ('onShowRoute','onClose','onToggleCollapsed','onEditPace','onStart','onSave','onPlan','onChoose')),
 'seguranca sem inicio automatico': 'onPressed: onStart' in widget and 'onStart: _startPreviewNavigation' in screen,
 'nao inventa relevo': 'Relevo, qualidade e tipo de via: sem dados comparáveis nesta prévia.' in widget,
 'aviso offline mantido': 'Trajeto salvo pode ser consultado offline; novos cálculos exigem internet.' in widget,
 'testes widgets presentes': test.count('testWidgets(')>=5,
 'contratos antigos ainda ativos': all((root/'tool'/x).exists() for x in ('check_map_refactor_233.py','check_map_refactor_234.py','check_route_preview_229.py')),
 'parte offline preservada': "part 'map_monitoring_offline_support.dart';" in screen,
}
for k,v in checks.items():
 if not v: raise SystemExit('ERRO refatoracao 235: '+k)
print(f'Extracao de pre-visualizacao 235: {len(checks)} contratos OK')
