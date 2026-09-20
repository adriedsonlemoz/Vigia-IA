#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODEL_DIR="$ROOT/assets/models"
mkdir -p "$MODEL_DIR"

fetch_model() {
  local out="$1"
  local url="$2"
  local min_bytes="$3"
  local label="$4"

  if [[ -f "$out" ]] && [[ $(wc -c < "$out") -ge $min_bytes ]]; then
    echo "$label ja presente: $out"
    return 0
  fi

  echo "Baixando $label..."
  curl -fL --retry 3 --retry-delay 2 "$url" -o "$out.tmp"
  local size
  size=$(wc -c < "$out.tmp")
  if [[ $size -lt $min_bytes ]]; then
    echo "Download invalido de $label: apenas $size bytes" >&2
    rm -f "$out.tmp"
    return 1
  fi
  mv "$out.tmp" "$out"
  echo "$label salvo em $out ($size bytes)."
}

if ! fetch_model \
  "$MODEL_DIR/efficientdet_lite0.tflite" \
  "https://storage.googleapis.com/download.tensorflow.org/models/tflite/task_library/object_detection/rpi/lite-model_efficientdet_lite0_detection_metadata_1.tflite" \
  3000000 \
  "EfficientDet-Lite0"; then
  echo "Aviso: EfficientDet-Lite0 indisponivel; o build seguira com o SSD de fallback." >&2
fi

# Fallback mantido para aparelhos/runtime que eventualmente recusem o modelo
# principal. O app tenta EfficientDet primeiro e usa SSD somente se necessário.
fetch_model \
  "$MODEL_DIR/ssd_mobilenet_v1.tflite" \
  "https://storage.googleapis.com/download.tensorflow.org/models/tflite/task_library/object_detection/android/lite-model_ssd_mobilenet_v1_1_metadata_2.tflite" \
  2000000 \
  "SSD MobileNet V1 (fallback)"
