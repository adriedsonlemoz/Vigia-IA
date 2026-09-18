#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/assets/models/ssd_mobilenet_v1.tflite"
URL="https://storage.googleapis.com/download.tensorflow.org/models/tflite/task_library/object_detection/android/lite-model_ssd_mobilenet_v1_1_metadata_2.tflite"
EXPECTED_MIN_BYTES=2000000

if [[ -f "$OUT" ]] && [[ $(wc -c < "$OUT") -ge $EXPECTED_MIN_BYTES ]]; then
  echo "Modelo ja presente: $OUT"
  exit 0
fi

echo "Baixando SSD MobileNet V1 com pos-processamento SSD..."
curl -fL --retry 3 --retry-delay 2 "$URL" -o "$OUT.tmp"
SIZE=$(wc -c < "$OUT.tmp")
if [[ $SIZE -lt $EXPECTED_MIN_BYTES ]]; then
  echo "Download invalido: apenas $SIZE bytes" >&2
  rm -f "$OUT.tmp"
  exit 1
fi
mv "$OUT.tmp" "$OUT"
echo "Modelo salvo em $OUT ($SIZE bytes)."
