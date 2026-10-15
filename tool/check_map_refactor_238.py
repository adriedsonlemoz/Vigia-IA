#!/usr/bin/env python3
"""Verifica extração sem alteração de comportamento do controle de gravação (1.0.238)."""
from pathlib import Path
import hashlib
import re

root = Path(__file__).resolve().parents[1]
screen = (root / 'lib/screens/map_monitoring_screen.dart').read_text(encoding='utf-8')
widget = (root / 'lib/widgets/map_navigation_record_control.dart').read_text(encoding='utf-8')
tests = (root / 'test/map_navigation_record_control_test.dart').read_text(encoding='utf-8')
gate = (root / 'tool/verify_project.sh').read_text(encoding='utf-8')
source = widget[widget.index('/// Gravacao integrada'):].strip()
checks = {
  'codigo de widget identico apos renomeacao':
      hashlib.sha256(source.encode()).hexdigest() ==
      '077cf1d261036db3bc234c1e75aa1022cb29193eef8ede764d048b24cf323a42',
  'widget publico no arquivo proprio':
      'class MapNavigationRecordControl extends StatelessWidget {' in widget,
  'tela referencia novo modulo':
      screen.count("import '../widgets/map_navigation_record_control.dart';") == 1,
  'dois pontos de uso preservados':
      len(re.findall(r'recordControl:\s*MapNavigationRecordControl\(', screen)) == 2,
  'sem classe antiga na tela':
      '_NavigationRecordControl' not in screen,
  'parametros recebidos na classe':
      all('required this.'+name in widget for name in (
          'recording','paused','canRecord','hasRoute','onToggleRecording',
          'onTogglePause','onExport')),
  'entradas iguais nos dois pontos':
      all(screen.count(name+':') >= 2 for name in (
          'recording','paused','canRecord','hasRoute',
          'onToggleRecording','onTogglePause','onExport')),
  'GPS controla habilitacao de gravar':
      'onPressed: canRecord ? onToggleRecording : null' in widget,
  'rotulo GPS indisponivel mantido':
      "'GPS indisponível'" in widget,
  'pausa e retomada preservadas':
      all(t in widget for t in ("'Retomar gravação'", "'Pausar gravação'",'onPressed: onTogglePause')),
  'exportacao so em rota existente':
      "if (hasRoute)" in widget and "value: 'gpx'" in widget,
  'encerrar nao se confunde com exportar':
      "if (action == 'stop') onToggleRecording();" in widget and
      "if (action == 'gpx') onExport();" in widget,
  'sem nova temporizacao ou estado no modulo':
      all(t not in widget for t in ('StatefulWidget', 'initState(', 'setState(',
                                    'dispose(', 'Timer(', 'StreamSubscription',
                                    'Geolocator','HttpClient')),
  'sem dependencia circular':
      'map_monitoring_screen.dart' not in widget and 'part of' not in widget,
  'widget ainda sem service direto':
      'MapRouteService' not in widget and 'LocationTrackingService' not in widget,
  'legado 214 nao foi desativado':
      "grep -Fq 'class MapNavigationRecordControl extends StatelessWidget' lib/widgets/map_navigation_record_control.dart" in gate and
      "grep -Fc 'recordControl: MapNavigationRecordControl('" in gate,
  'contratos 233 a 237 preservados':
      all(f'python3 tool/check_map_refactor_{v}.py' in gate for v in (233,234,235,236,237)),
  'novo contrato ativado no gate':
      'python3 tool/check_map_refactor_238.py' in gate,
  'testes Flutter de interacao adicionados':
      tests.count('testWidgets(') >= 7,
  'testes cobrem GPS e GPX':
      all(t in tests for t in ('GPS ausente', 'Exportar GPX', 'rota insuficiente', 'Retomar gravação')),
}
failed = [name for name,ok in checks.items() if not ok]
if failed:
    raise SystemExit('ERRO refatoracao 238: '+', '.join(failed))
print(f'Gravacao modular 238: {len(checks)} contratos OK')
