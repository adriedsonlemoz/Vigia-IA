#!/usr/bin/env python3
"""Regression gate for the 10 public map widgets rejected by Flutter analyze #194.

Does not suppress Flutter lints or replace flutter analyze in CI.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
TARGETS = {
    'map_navigation_metrics.dart': ('MapNavigationMetricCell', 'MapNavigationPoiChip'),
    'map_navigation_record_control.dart': ('MapNavigationRecordControl',),
    'map_route_alternatives_button.dart': ('MapRouteAlternativesButton',),
    'map_route_preview_card.dart': ('MapRoutePreviewCard',),
    'map_status_indicators.dart': ('MapSystemHud', 'MapFocusSpeedPill'),
    'map_telemetry_strip.dart': ('MapTelemetryStrip',),
    'map_zoom_controls.dart': ('MapControlGap', 'MapZoomCluster'),
}


def audit(contents: dict[str, str]) -> list[str]:
    problems = []
    for filename, classes in TARGETS.items():
        content = contents[filename]
        for klass in classes:
            declaration = re.search(r'\bclass\s+' + klass + r'\s+extends\s+StatelessWidget\s*\{', content)
            # Only the public constructor is relevant to use_key_in_widget_constructors.
            ctor = re.search(r'\bconst\s+' + klass + r'\s*\(\s*\{(?P<params>[^}]*)\}\s*\)', content)
            if declaration is None or ctor is None:
                problems.append(f'{filename}:{klass}: declaracao ou construtor ausente')
            elif not re.search(r'\bsuper\.key\s*,', ctor.group('params')):
                problems.append(f'{filename}:{klass}: super.key ausente')
    return problems


def all_contents() -> dict[str, str]:
    return {name: (ROOT / 'lib' / 'widgets' / name).read_text(encoding='utf-8') for name in TARGETS}


if __name__ == '__main__':
    failures = audit(all_contents())
    if failures:
        raise SystemExit('FALHA do buildfix 239: ' + '; '.join(failures))
    workflow = (ROOT / '.github/workflows/android-apk.yml').read_text(encoding='utf-8')
    if 'flutter analyze --fatal-infos --fatal-warnings' not in workflow:
        raise SystemExit('FALHA: gate de analise rigorosa removido')
    print(f'Buildfix 239: {sum(map(len, TARGETS.values()))} construtores publicos com super.key; gate Flutter preservado.')
