#!/usr/bin/env bash
# Não altera nenhum APK já publicado; gera o asset antes do flutter build.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -f assets/models/yolo26s.tflite ]] && [[ $(wc -c < assets/models/yolo26s.tflite) -ge 3000000 ]]; then
  python3 tool/export_yolo26s.py
  exit 0
fi
python3 -m pip install --disable-pip-version-check --quiet 'ultralytics>=8.4,<9' 'tensorflow>=2.17,<3'
python3 tool/export_yolo26s.py
