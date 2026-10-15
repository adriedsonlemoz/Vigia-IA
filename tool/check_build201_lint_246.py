#!/usr/bin/env python3
"""Prevent regression of the --fatal-infos Dart lint from Android-APK #201."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "lib/screens/mcrp_camera_screen.dart"


def check(source: str) -> None:
    on_frame = re.search(
        r"Future<void> _onFrame\(RgbFrame frame, int generation\) async \{(?P<body>.*?)\n  \}",
        source,
        flags=re.S,
    )
    if not on_frame:
        raise ValueError("Método _onFrame ausente")
    body = on_frame.group("body")
    guard = re.search(
        r"if\s*\(\s*!widget\.analysisEnabled\s*\|\|\s*!_aiReady\s*\|\|\s*_processing\s*\|\|\s*"
        r"detector\s*==\s*null\s*\|\|\s*generation\s*!=\s*_generation\s*\)"
        r"\s*\{\s*return;\s*\}",
        body,
        flags=re.S,
    )
    if not guard:
        raise ValueError("A guarda de inferência precisa manter todas as condições e chaves no retorno")
    # Do not suppress the lint globally. Analyzer still remains a CI gate.
    if "ignore_for_file: curly_braces_in_flow_control_structures" in source:
        raise ValueError("Lint não pode ser suprimido")


if __name__ == "__main__":
    check(SOURCE.read_text(encoding="utf-8"))
    print("Buildfix 246: guarda de IA com bloco obrigatório preservado.")
