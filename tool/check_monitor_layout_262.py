#!/usr/bin/env python3
"""A compact, source-only contract for Ao vivo layout release 262."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def check_source(files=None):
    def read(file):
        return (ROOT / file).read_text(encoding='utf-8') if files is None else files[file]
    portrait = read('lib/screens/monitor_screen_portrait.dart')
    monitor = read('lib/screens/monitor_screen_multicamera.dart')
    components = read('lib/screens/monitor_screen_components.dart')
    overlay = read('lib/widgets/detection_overlay.dart')
    errors=[]
    def needs(ok, label):
        if not ok: errors.append(label)
    needs('_buildDualCameraStage(context, portraitEmbedded: portraitEmbedded)' in monitor, 'Dual view is missing')
    needs('Expanded(child: primary)' in monitor and 'Expanded(child: second)' in monitor, 'Both feeds must be large')
    needs('_buildPortraitPictureInPictureStage' not in monitor, 'Floating video miniatura is still used')
    needs('secondary != null &&' in portrait and 'constraints.maxHeight * 0.83' in portrait, 'Dual height is not expanded')
    needs('if (secondaryType != null)' in components and 'if (embedded)' in components, 'Single camera should not show secondary info')
    needs('_CompactCameraTelemetryCard(' in components and 'secondaryTelemetry: secondaryTelemetry' in components, 'Per-camera status is missing')
    needs('batteryTemperatureC' in components and 'batteryPercent' in components, 'Battery and temperature not rendered')
    needs("temp == null ? '—'" in components, 'Unavailable temperatures are not explicit')
    needs('onModelTap: embedded' in monitor and 'onDiagnosticTap: embedded' in monitor, 'IA buttons lost')
    needs('onModelTap: () =>' in portrait and 'onDiagnosticTap: () =>' in portrait, 'Single camera IA buttons lost')
    needs('text: detection.displayLabel' in overlay, 'Detection name missing')
    needs("'#\u0024trackId" not in overlay and 'confidence * 100' not in overlay, 'Overlay still exposes ids/percentages')
    needs('labels.take(3).join' in portrait and "'#\u0024primaryTrackId" not in portrait, 'Detection summary still exposes ids')
    needs('_buildSecondaryFilledPreview' in monitor, 'Second camera should fill its panel')
    return errors

if __name__ == '__main__':
    problems=check_source()
    if problems: raise SystemExit('; '.join(problems))
    print('Ao vivo 1.0.262: layout, sensores reais e rótulos aprovados.')
