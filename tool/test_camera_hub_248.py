#!/usr/bin/env python3
import subprocess, tempfile, unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

class CameraHub248Tests(unittest.TestCase):
 def test_contract(self):
  subprocess.run(['python3',str(ROOT/'tool/check_camera_hub_248.py')], check=True, capture_output=True)
 def test_home_card_restored(self):
  text=(ROOT/'lib/screens/home_screen_redesign.dart').read_text()
  self.assertIn("title: 'Minha Câmera'", text)
  self.assertIn("onTap: () => _openScreen(const McrpCameraScreen()),", text)
 def test_migration_not_losing_source_before_save(self):
  text=(ROOT/'lib/services/minha_camera_registry_migration.dart').read_text()
  self.assertLess(text.index('await cameras.save('), text.index('await legacy.remove('))
 def test_no_secret_in_camera_card(self):
  screen=(ROOT/'lib/screens/multi_camera_screen.dart').read_text()
  self.assertIn("MinhaCameraLiveUrl.parse(endpoint.address ?? '')?.host",screen)
 def test_mjpeg_source_not_rtsp(self):
  source=(ROOT/'lib/models/camera_source_selector.dart').read_text()
  self.assertRegex(source, r'CameraEndpointType.remotePhone => VideoSourceConfig\(\s+type: VideoSourceType.remotePhone')
 def test_deletion_does_not_reimport_legacy(self):
  screen=(ROOT/'lib/screens/multi_camera_screen.dart').read_text()
  self.assertIn('await _clearLegacyOnDelete(camera)',screen)
  service=(ROOT/'lib/services/minha_camera_registry_migration.dart').read_text()
  self.assertIn('await legacy.remove(item.liveUrl)',service)
 def test_monitor_entry(self):
  monitor=(ROOT/'lib/screens/monitor_screen.dart').read_text()
  self.assertIn("tooltip: 'Voltar ao início'", monitor)
if __name__ == '__main__': unittest.main()
