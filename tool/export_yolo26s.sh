#!/usr/bin/env bash
# Gera o modelo no CI; falha fechada se a conversão ou a validação não funcionar.
set -euo pipefail
cd "$(dirname "$0")/.."

# O PyTorch 2.13 e o torchvision 0.28 são um par oficial. O LiteRT Torch
# 0.9.4 requer esta linha do PyTorch; deixar o pip trocar apenas torch
# (como ocorreu no build 218) produz um ambiente inconsistente.
# Interpreter separado: não instala tensorflow só para conferir o .tflite.
python3 -m pip install --disable-pip-version-check --quiet \
  'ai-edge-litert==2.2.0' 'numpy>=1.26,<3'

if [[ -f assets/models/yolo26s.tflite ]] && [[ $(wc -c < assets/models/yolo26s.tflite) -ge 3000000 ]]; then
  if python3 tool/export_yolo26s.py; then
    echo 'YOLO26s em cache: validação de tensores aprovada.'
    exit 0
  fi
  echo 'Cache YOLO26s inválido; refazendo exportação.' >&2
  rm -f assets/models/yolo26s.tflite
fi

python3 -m pip install --disable-pip-version-check --quiet \
  'torch==2.13.0' 'torchvision==0.28.0' \
  'litert-torch==0.9.4' 'ultralytics>=8.4.83,<9'

# Evita que o resolvedor de dependências atualize apenas um dos dois pacotes.
python3 - <<'PY'
import torch
import torchvision
if not torch.__version__.startswith('2.13.0') or not torchvision.__version__.startswith('0.28.0'):
    raise SystemExit(f'Par PyTorch incompatível: torch={torch.__version__}, torchvision={torchvision.__version__}')
print(f'Exportador: torch={torch.__version__}, torchvision={torchvision.__version__}')
PY
python3 tool/export_yolo26s.py
