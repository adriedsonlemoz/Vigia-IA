import unittest
from pathlib import Path
import subprocess
R=Path(__file__).resolve().parents[1]
class TestMcrp245(unittest.TestCase):
 def test_structural_contracts(self):
  p=subprocess.run(['python3',str(R/'tool/check_mcrp_245.py')],capture_output=True,text=True)
  self.assertEqual(p.returncode,0,p.stderr+p.stdout)
 def test_no_legacy_by_default(self):
  t=(R/'lib/screens/mcrp_camera_screen.dart').read_text()
  self.assertIn('bool _legacy = false;',t)
  self.assertIn('var legacy = false;',t)
 def test_compatibility_error_only_404(self):
  t=(R/'lib/services/mcrp_client.dart').read_text()
  self.assertIn("error.message == 'MCRP HTTP 404'",t)
  self.assertNotIn("error.message != 'MCRP HTTP 403'",t)
 def test_public_media_store(self):
  t=(R/'android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt').read_text()
  self.assertIn('MediaStore.MediaColumns.IS_PENDING, 0',t)
  self.assertIn('contentResolver.delete(uri, null, null)',t)
 def test_low_cost_stream(self):
  t=(R/'lib/screens/mcrp_camera_screen.dart').read_text()
  self.assertIn('analysisInterval: const Duration(milliseconds: 800)',t)
  self.assertIn('if (!widget.analysisEnabled || !_aiReady || _processing ||',t)
 def test_no_model_transmission(self):
  t=(R/'lib/screens/mcrp_camera_screen.dart').read_text()
  self.assertIn('ObjectDetectionService()',t)
  self.assertNotIn("remoteInference",t)
if __name__=='__main__':unittest.main()
