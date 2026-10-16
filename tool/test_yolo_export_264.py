"""Regressão do exportador YOLO26s e downloads no CI 218."""
import importlib.util
import unittest
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[1]


def read(file):
    return (ROOT / file).read_text(encoding='utf-8')


class ExportYolo264Test(unittest.TestCase):
    def test_cholesky_legacy_alias_only_when_missing(self):
        spec = importlib.util.spec_from_file_location('vigia_yolo_export_264', ROOT / 'tool/export_yolo26s.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        modern = object()
        aten = SimpleNamespace(linalg_cholesky=modern)
        torch_stub = SimpleNamespace(ops=SimpleNamespace(aten=aten))
        self.assertTrue(module.ensure_legacy_cholesky_compatibility(torch_stub))
        self.assertIs(aten.cholesky, modern)
        self.assertFalse(module.ensure_legacy_cholesky_compatibility(torch_stub))

    def test_missing_modern_op_fails_explicitly(self):
        spec = importlib.util.spec_from_file_location('vigia_yolo_export_264', ROOT / 'tool/export_yolo26s.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with self.assertRaisesRegex(RuntimeError, 'linalg_cholesky'):
            module.ensure_legacy_cholesky_compatibility(SimpleNamespace(ops=SimpleNamespace(aten=SimpleNamespace())))

    def test_torch_torchvision_pinned_as_official_pair(self):
        shell = read('tool/export_yolo26s.sh')
        for token in ('torch==2.13.0', 'torchvision==0.28.0', 'litert-torch==0.9.4'):
            self.assertIn(token, shell)
        self.assertIn("python3 tool/export_yolo26s.py", shell)
        self.assertIn('ai-edge-litert==2.2.0', shell)
        self.assertNotIn("'tensorflow>=2.17,<3'", shell)

    def test_interpreter_and_fail_closed_release(self):
        exporter = read('tool/export_yolo26s.py')
        workflow = read('.github/workflows/android-apk.yml')
        self.assertIn('from ai_edge_litert.interpreter import Interpreter', exporter)
        self.assertIn('model.export(format=\'litert\', imgsz=640)', exporter)
        self.assertIn('timeout 900 bash ./tool/export_yolo26s.sh', workflow)
        self.assertIn('APK sem YOLO26s real', workflow)
        self.assertIn('test "$(wc -c < assets/models/yolo26s.tflite)" -ge 3000000', workflow)

    def test_efficientdet_lite2_official_mediapipe_url(self):
        script = read('tool/fetch_model.sh')
        self.assertIn('mediapipe-models/object_detector/efficientdet_lite2/float32/1/efficientdet_lite2.tflite', script)
        self.assertNotIn('lite-model_efficientdet_lite2_detection_metadata_1.tflite', script)


if __name__ == '__main__':
    unittest.main()
