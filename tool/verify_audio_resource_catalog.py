#!/usr/bin/env python3
from pathlib import Path
import re
import sys


root = Path(__file__).resolve().parents[1]
dart = (root / "lib/models/audio_slot.dart").read_text(encoding="utf-8")
catalog = (root / "tool/android/AudioResourceCatalog.kt").read_text(encoding="utf-8")
raw_dir = root / "android/app/src/main/res/raw"

dart_slots = set(re.findall(r"AudioSlotDefinition\(id: '([a-z0-9_]+)'", dart))
catalog_entries = re.findall(r'"([a-z0-9_]+)" to R\.raw\.([a-z0-9_]+)', catalog)
catalog_slots = {slot for slot, resource in catalog_entries if slot == resource}
raw_slots = {path.stem for path in raw_dir.glob("*.m4a")}

errors = []
if len(catalog_entries) != len(catalog_slots):
    errors.append("o catálogo possui entrada duplicada ou slot diferente do nome R.raw")
if dart_slots != catalog_slots:
    errors.append(
        f"catálogo Android diverge do Dart: ausentes={sorted(dart_slots - catalog_slots)}, "
        f"extras={sorted(catalog_slots - dart_slots)}"
    )
if raw_slots != catalog_slots:
    errors.append(
        f"arquivos res/raw divergem do catálogo: ausentes={sorted(catalog_slots - raw_slots)}, "
        f"extras={sorted(raw_slots - catalog_slots)}"
    )
if len(catalog_slots) != 78:
    errors.append(f"esperados 78 slots, encontrados {len(catalog_slots)}")

if errors:
    for error in errors:
        print(f"ERRO: {error}", file=sys.stderr)
    raise SystemExit(1)

print("Catálogo de áudio Android validado: 78 slots com referências R.raw explícitas.")
