#!/usr/bin/env python3
"""Verificação estática específica do mapa/rádio 1.0.219.
Não substitui flutter analyze/test ou teste de rede real.
"""
from pathlib import Path
root = Path(__file__).resolve().parents[1]


def text(path):
    return (root / path).read_text(encoding='utf-8')


def check(ok, message):
    if not ok:
        raise SystemExit(f'FALHA DE REGRESSÃO 1.0.219: {message}')

poi = text('lib/services/route_explorer_service.dart')
city = text('lib/services/map_destination_search_service.dart')
radio = text('lib/widgets/map_radio_panel.dart')
history = text('lib/services/radio_recent_history.dart')
mapui = text('lib/screens/map_monitoring_screen.dart')
check('overpass.private.coffee/api/interpreter' in poi and '_fetchPoiResponse(' in poi,
      'fallback de pontos úteis ausente')
check('if (requestedKm > 5) 5' in poi and 'if (requestedKm > 10) 10' in poi,
      'busca progressiva de pontos úteis ausente')
check('effectiveOnlineRadiusKm' in poi and 'service.effectiveOnlineRadiusKm' in mapui,
      'raio efetivamente consultado não é exibido')
check('var quickFailed = false;' in city and 'expandedFailed' in city and
      'Uma falha na fase curta não deve impedir a busca regional' in city,
      'uma falha na fase rápida interrompe a ampliação')
check('rememberRecentPlace' in city and 'recentPlaces' in city and
      'service.rememberRecentPlace(item)' in mapui,
      'histórico local de destinos ausente')
check('service.updateLocalQuery(' in mapui and 'onChanged: (value)' in mapui,
      'sugestões durante digitação ausentes')
check('maximumEntries = 20' in history and 'radio_recent_history.json' in history,
      'histórico persistente de rádio ausente')
check("status.state == 'tocando' && _pendingStation != null" in radio,
      'histórico registra estação sem confirmar reprodução')
check('enum _RadioSection { discover, recent, favorites, manual }' in radio and
      'String _radioFilterLabel(' in radio and '_maxBitrate' in radio,
      'abas/filtros da rádio ausentes')
check('height: items.isEmpty && !service.loading ? 470 : 690' in mapui and
      'height: filtered.isEmpty && !service.loading ? 420 : 650' in mapui,
      'diálogos vazios não foram compactados')
check('class RadioSleepTimer' in text('lib/services/radio_sleep_timer.dart') and
      'RadioSleepTimer.schedule(' in radio, 'temporizador local da rádio ausente')
check('1.0.221+221' in text('pubspec.yaml'), 'versão divergente')
print('Regressões locais de mapa/rádio 1.0.219: OK')
