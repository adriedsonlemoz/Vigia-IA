#!/usr/bin/env python3
import subprocess,unittest
from pathlib import Path
R=Path(__file__).resolve().parents[1]
class HomeModes252Tests(unittest.TestCase):
 def test_contract(self):
  subprocess.run(['python3',str(R/'tool/check_home_modes_252.py')],check=True,capture_output=True)
 def test_mcrp_remains_visible_in_camera_hub(self):
  src=(R/'lib/screens/multi_camera_screen.dart').read_text()
  self.assertIn('McrpCameraScreen(',src)
  self.assertIn('initialLiveUrl: camera.address',src)
 def test_home_has_only_four_main_cards(self):
  home=(R/'lib/screens/home_screen_redesign.dart').read_text()
  self.assertEqual(4,home.count('VigiaModeCard('))
  self.assertNotIn("title: 'Minha Câmera'",home)
 def test_saved_camera_records_not_changed(self):
  self.assertTrue((R/'lib/services/mcrp_saved_cameras_store.dart').exists())
  self.assertTrue((R/'lib/services/camera_registry_service.dart').exists())
if __name__=='__main__':unittest.main()
