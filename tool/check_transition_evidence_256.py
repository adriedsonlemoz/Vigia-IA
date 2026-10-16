#!/usr/bin/env python3
"""Checks conservative entry/exit event routing without assuming a Flutter SDK."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def check_sources(tracker: str, controller: str, speech: str) -> None:
    required = [
        'this.verifiedZoneTransitionsOnly = false',
        'if (!verifiedZoneTransitionsOnly &&',
        '_updateVerifiedZones(',
        'if (isNew) {',
        'track.pendingZoneHits < 2',
        'track.pendingMotion',
        'displacement >= 0.055',
        'detection.confidence >= 0.60',
        'zone.zone.isFullFrame',
        'zone.isFullFrame',
        'isMoving?.call(detection) ?? false',
    ]
    for marker in required:
        if marker not in tracker:
            raise AssertionError(f'Tracker não possui salvaguarda: {marker}')
    for marker in ('verifiedZoneTransitionsOnly: true', 'isMoving: (detection)', '_sameDetectionRegion'):
        if marker not in controller:
            raise AssertionError(f'Controller não aplicou salvaguarda: {marker}')
    for marker in ('sameZoneSpeech', 'Duration(seconds: 20)', 'sharedKey'):
        if marker not in speech:
            raise AssertionError(f'Cooldown de fala ausente: {marker}')


def check() -> None:
    check_sources(
        (ROOT / 'lib/services/object_tracker.dart').read_text(encoding='utf-8'),
        (ROOT / 'lib/controllers/monitor_controller.dart').read_text(encoding='utf-8'),
        (ROOT / 'lib/controllers/monitor_controller_event_support.dart').read_text(encoding='utf-8'),
    )
    t = (ROOT / 'test/object_tracker_verified_transitions_test.dart').read_text(encoding='utf-8')
    for phrase in ('perda e retorno', 'cruzamento observado', 'oscilação perto da borda',
                   'sem movimento evidenciado', 'tela inteira'):
        if phrase not in t:
            raise AssertionError(f'Teste de cenário ausente: {phrase}')


if __name__ == '__main__':
    check()
    print('Contratos preventivos de eventos/áreas 256: OK')
