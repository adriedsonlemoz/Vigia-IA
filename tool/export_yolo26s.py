#!/usr/bin/env python3
"""Gera YOLO26s LiteRT/TFLite reproduzivelmente no runner do GitHub.

Exportação do checkpoint público AGPL-3.0 Ultralytics. Não executa no Android.
Uso: python3 tool/export_yolo26s.py
"""
from __future__ import annotations

from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'assets/models/yolo26s.tflite'


def validate(path: Path) -> None:
    import numpy as np
    from ai_edge_litert.interpreter import Interpreter

    detector = Interpreter(model_path=str(path), num_threads=2)
    detector.allocate_tensors()
    inp = detector.get_input_details()
    out = detector.get_output_details()
    if len(inp) != 1 or len(out) != 1:
        raise ValueError('YOLO26s requer uma entrada e uma saída.')
    input_shape = list(inp[0]['shape'])
    output_shape = list(out[0]['shape'])
    if len(input_shape) != 4 or input_shape[0] != 1 or (
        input_shape[1] != 3 and input_shape[3] != 3
    ):
        raise ValueError(f'Formato de entrada incompatível: {input_shape}')
    if len(output_shape) != 3 or output_shape[0] != 1 or not (
        output_shape[2] == 6 or output_shape[1] == 84 or output_shape[2] == 84
    ):
        raise ValueError(f'Formato de saída incompatível: {output_shape}')
    if inp[0]['dtype'] not in (np.float32, np.uint8):
        raise ValueError(f'Tipo de entrada incompatível: {inp[0]["dtype"]}')
    if out[0]['dtype'] != np.float32:
        raise ValueError(f'Tipo de saída incompatível: {out[0]["dtype"]}')
    if path.stat().st_size < 3_000_000:
        raise ValueError('Modelo incompleto ou muito pequeno.')
    print(f'YOLO26s validado: {input_shape} → {output_shape}, {path.stat().st_size} bytes')



def ensure_legacy_cholesky_compatibility(torch_module) -> bool:
    """Compatibilidade de importação para conversores LiteRT antigos.

    Não reintroduz kernel obsoleto: apenas fornece ao catálogo de operadores
    a referência moderna equivalente que o conversor usa como chave.
    Retorna True quando precisou adaptar o ambiente.
    """
    aten = torch_module.ops.aten
    if hasattr(aten, 'cholesky'):
        return False
    if not hasattr(aten, 'linalg_cholesky'):
        raise RuntimeError('Nem cholesky nem linalg_cholesky disponíveis no PyTorch.')
    aten.cholesky = aten.linalg_cholesky
    return True


def main() -> int:
    if DEST.exists() and DEST.stat().st_size >= 3_000_000:
        validate(DEST)
        return 0

    # Compatibilidade limitada ao processo de exportação. No PyTorch 2.13,
    # aten.cholesky foi removido, mas LiteRT Torch 0.9.4 ainda consulta a
    # referência legada ao importar seu registro de conversores. Atribuir
    # a operação moderna evita o erro de importação; o modelo YOLO26s não
    # utiliza Cholesky em seu grafo. Não modifica a execução no Android.
    import torch
    if ensure_legacy_cholesky_compatibility(torch):
        print('Compatibilidade de exportação: aten.cholesky → aten.linalg_cholesky')

    from ultralytics import YOLO

    model = YOLO('yolo26s.pt')
    # As exportações do YOLO26 admitem cabeças diferentes. nms=False
    # solicita saída (N,300,6) end-to-end quando suportado. Em runtimes
    # que usam saída raw (1,84,8400), o decodificador do Vigia IA suporta NMS.
    exported = model.export(format='litert', imgsz=640)
    source = Path(str(exported)).resolve()
    if source.is_dir():
        candidates = sorted(source.rglob('*.tflite'), key=lambda p: ('float16' not in p.name.lower(), p.name))
        if not candidates:
            raise RuntimeError(f'Exportação não produziu arquivo TFLite em {source}')
        source = candidates[0]
    if not source.is_file() or source.suffix != '.tflite':
        raise RuntimeError(f'Exportação não gerou um .tflite: {exported}')
    validate(source)
    DEST.parent.mkdir(parents=True, exist_ok=True)
    temporary = DEST.with_suffix('.tflite.tmp')
    shutil.copyfile(source, temporary)
    temporary.replace(DEST)
    print('Modelo oficial exportado para assets/models/yolo26s.tflite')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as exc:
        print(f'Exportação YOLO26s indisponível: {exc}', file=sys.stderr)
        sys.exit(1)
