#!/usr/bin/env python3
"""Regressão estática do workflow #185. Não substitui `flutter analyze`."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
mapui = (root / 'lib/screens/map_monitoring_screen.dart').read_text(encoding='utf-8')
radio = (root / 'lib/widgets/map_radio_panel.dart').read_text(encoding='utf-8')
history = (root / 'lib/services/radio_recent_history.dart').read_text(encoding='utf-8')
offline = (root / 'lib/widgets/offline_map_manager_sheet.dart').read_text(encoding='utf-8')


def must(condition: bool, label: str) -> None:
    if not condition:
        raise SystemExit(f'Buildfix #185: FALHA: {label}')


must("import 'dart:ui' as ui;" in mapui, 'alias explícito para o Path do Canvas')
painter = mapui.split('class _MapStyleThumbnailPainter extends CustomPainter {', 1)[1].split('\nclass _RoutePreviewCard', 1)[0]
must(len(re.findall(r'\bui\.Path\s*\(', painter)) == 4, 'quatro paths de Canvas com ui.Path')
must(not re.search(r'(?<![.\w])Path\s*\(', painter), 'não usar Path genérico do Flutter Map no Canvas')
must('_mapStyleIcon(' not in mapui, 'método _mapStyleIcon removido')
must('_KeyMetric' not in offline, 'widget _KeyMetric não utilizado removido')
must('Widget _radioFilterMenu<T extends Object>' in radio, 'genérico não nulo compatível com Object')
must('String _radioFilterLabel(Object value)' in radio, 'filtro permanece tipado como Object')
must('!station.tags.toLowerCase().contains(_genre.toLowerCase())) {\n      return false;\n    }' in radio, 'if de gênero com chaves')
must('!station.language.toLowerCase().contains(_language.toLowerCase())) {\n      return false;\n    }' in radio, 'if de idioma com chaves')
must('if (_maxBitrate > 0 && station.bitrate > _maxBitrate) {\n      return false;\n    }' in radio, 'if de bitrate com chaves')
must("local.day == now.day) {\n      return 'hoje';\n    }" in radio, 'if da data recente com chaves')
must('factory RadioRecentHistory({File? file}) => RadioRecentHistory._(file);' in history, 'API nomeada pública preservada')
must('RadioRecentHistory._(this._file);' in history, 'campo inicializado com formal inicializador')
print('Buildfix #185: conflitos de Path, filtro rádio e avisos locais verificados.')
