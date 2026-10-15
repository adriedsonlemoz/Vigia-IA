#!/usr/bin/env python3
"""Prevent the three fatal Dart infos reported in Android APK #198.

Static guard only; not a replacement for flutter analyze/test in CI.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def audit(registry: str, url: str, source: str) -> list[str]:
    errors = []
    if "final controlPath = minhaCamera.path.replaceFirst('/live/', '/control/');" not in registry:
        errors.append('healthcheck endpoint control path changed')
    if "minhaCamera.replace(path: '$controlPath/status')" not in registry:
        errors.append('healthcheck no longer uses interpolation')
    if "replaceFirst('/live/', '/control/') + '/status'" in registry:
        errors.append('prefer_interpolation_to_compose_strings reintroduced')
    condition = """        uri.hasQuery || uri.hasFragment) {
      return null;
    }"""
    if condition not in url:
        errors.append('curly_braces_in_flow_control_structures reintroduced')
    if "uri.hasQuery || uri.hasFragment) return null;" in url:
        errors.append('unbraced return reintroduced')
    if "import 'dart:typed_data';" in source:
        errors.append('unnecessary_import reintroduced')
    if "import 'package:flutter/foundation.dart';" not in source or "Uint8List" not in source:
        errors.append('required Flutter foundation/byte stream contract changed')
    return errors


def check() -> list[str]:
    return audit(
        (ROOT/'lib/services/camera_registry_service.dart').read_text(encoding='utf-8'),
        (ROOT/'lib/services/minha_camera_live_url.dart').read_text(encoding='utf-8'),
        (ROOT/'lib/sources/minha_camera_mjpeg_source.dart').read_text(encoding='utf-8'),
    )

if __name__ == '__main__':
    problems=check()
    if problems:
        raise SystemExit('Android APK #198 lint regressions: '+'; '.join(problems))
    print('Buildfix 243: 3 avisos fatais de flutter analyze #198 eliminados estruturalmente.')
