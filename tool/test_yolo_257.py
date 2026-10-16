"""Regressão estrutural da integração YOLO26s (não executa TensorFlow/Flutter)."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


class YoloReceiverContracts(unittest.TestCase):
    def test_order_and_distinct_labelmaps(self):
        content = read('lib/services/object_detection_assets.dart')
        assert content.index("('YOLO26s',") < content.index("('EfficientDet-Lite2',")
        assert content.index("('EfficientDet-Lite2',") < content.index("('EfficientDet-Lite0',")
        self.assertIn('yoloLabels.length != 80', read('lib/services/object_detection_service.dart'))
        self.assertEqual(len(read('assets/models/yolo_coco80.txt').splitlines()), 80)

    def test_tensor_formats_and_preprocess(self):
        worker = read('lib/services/object_detection_worker.dart')
        prep = read('lib/services/detector_input_buffer.dart')
        decoded = read('lib/services/yolo_detection_decoder.dart')
        for expected in ('runtime.isYolo', 'yoloOutput', 'channelFirst',
                         'TensorType.float32', 'YoloDetectionDecoder.decode'):
            self.assertIn(expected, worker)
        self.assertIn('DetectorPixelNormalization.zeroToOne', prep)
        self.assertIn('padding = 0', prep)
        self.assertIn('return kept;', decoded)
        self.assertIn('return candidates.take(maxResults)', decoded)

    def test_transmitter_has_no_detector(self):
        # A etapa de transmissão não pode inicializar IA só para enviar.
        tx = read('lib/screens/transmitter_screen.dart') if (ROOT / 'lib/screens/transmitter_screen.dart').exists() else ''
        if tx:
            self.assertNotIn('ObjectDetectionService(', tx)
        self.assertIn("'type': 'detect'", read('lib/services/object_detection_service.dart'))

    def test_export_verifies_io_before_using_model(self):
        exporter = read('tool/export_yolo26s.py')
        ci = read('.github/workflows/android-apk.yml')
        self.assertIn('validate(source)', exporter)
        self.assertIn("YOLO('yolo26s.pt')", exporter)
        self.assertIn('timeout 600 bash ./tool/export_yolo26s.sh', ci)
        self.assertIn('flutter analyze --fatal-infos --fatal-warnings', ci)

    def test_version_and_license(self):
        self.assertRegex(read('pubspec.yaml'), r'(?m)^version: 1\.0\.\d+\+\d+$')
        self.assertIn('AGPL-3.0', read('THIRD_PARTY_NOTICES.md'))
        self.assertIn('YOLO26s', read('RELEASE-1.0.257.md'))


if __name__ == '__main__':
    unittest.main()
