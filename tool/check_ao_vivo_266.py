#!/usr/bin/env python3
"""Verificação independente da integração Ao vivo e telemetria 266 (sem Flutter)."""
from pathlib import Path
R=Path(__file__).resolve().parents[1]
def read(name):return (R/name).read_text(encoding='utf-8')
ui=read('lib/screens/monitor_screen_ai_tools.dart')
portrait=read('lib/screens/monitor_screen_portrait.dart')
monitor=read('lib/screens/monitor_screen.dart')
primary=read('lib/controllers/monitor_controller.dart')
secondary=read('lib/controllers/secondary_camera_controller.dart')
source=read('lib/sources/minha_camera_mjpeg_source.dart')
parser=read('lib/services/minha_camera_telemetry.dart')
assert '_buildAiDiagnosticBanner(context)' in portrait
assert 'dualNaturalHeight' in portrait
assert '(_secondaryController != null && _fillPreview)' in monitor
assert 'Timer.periodic(const Duration(seconds: 1)' in ui
assert 'segments.add(' in ui and 'run.events' in ui
assert '300, 600' in ui
assert 'Exportar dados' in ui and 'Copiar' in ui
assert 'source is MinhaCameraMjpegSource' in primary
assert 'source is MinhaCameraMjpegSource' in secondary
assert 'remoteStatusNotifier.value = MinhaCameraTelemetry.fromHeaders' in source
assert 'McrpAddress.parse(liveUrl)' in source
assert "boundedInt('x-battery-level', 0, 100)" in parser
assert "boundedInt('x-battery-temp-tenths', -400, 1000)" in parser
print('Ao vivo 266: contratos de vídeo, diagnóstico e telemetria aprovados.')
