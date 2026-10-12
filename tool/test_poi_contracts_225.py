"""Contratos estáticos complementares; não são testes Dart ou compilação."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

class PoiContracts225(unittest.TestCase):
    def test_result_provenance_is_persisted(self):
        model = (ROOT/'lib/models/route_explorer_models.dart').read_text()
        self.assertIn("'fetchedAt': fetchedAt!.toIso8601String()", model)
        self.assertIn("DateTime.tryParse(json['fetchedAt']", model)
    def test_online_fetch_has_http_backoff(self):
        service=(ROOT/'lib/services/route_explorer_service.dart').read_text()
        self.assertIn('_endpointPolicy.canAttempt', service)
        self.assertIn('httpStatus: response.statusCode', service)
        self.assertIn('_endpointPolicy.failed(endpoint', service)
        self.assertIn('Duration(seconds: 2)', service)
    def test_restore_marks_old_online_results_cache(self):
        service=(ROOT/'lib/services/route_explorer_service.dart').read_text()
        self.assertIn("_lastSource = 'cache'", service)
        self.assertIn("_lastSource != 'offline'", service)
    def test_poi_detail_source_distance_and_caveat(self):
        sheet=(ROOT/'lib/widgets/map_poi_details_sheet.dart').read_text()
        self.assertIn("'$distanceLabel em linha reta'", sheet)
        self.assertIn('RouteExplorerPoiProvenance.serviceDisclaimer', sheet)
        self.assertIn('height: math.min(desired, maxAvailable * 0.83)', sheet)

if __name__=='__main__':
    unittest.main()
