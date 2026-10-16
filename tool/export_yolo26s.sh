#!/usr/bin/env bash
# Não altera nenhum APK já publicado; gera o asset antes do flutter build.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -f assets/models/yolo26s.tflite ]] && [[ $(wc -c < assets/models/yolo26s.tflite) -ge 3000000 ]]; then
  if python3 tool/export_yolo26s.py; then
    exit 0
  fi
  echo 'Cache YOLO26s inválido; refazendo exportação.' >&2
  rm -f assets/models/yolo26s.tflite
fi
python3 -m pip install --disable-pip-version-check --quiet 'ultralytics>=8.4.83,<9' 'tensorflow>=2.17,<3'
python3 tool/export_yolo26s.py
