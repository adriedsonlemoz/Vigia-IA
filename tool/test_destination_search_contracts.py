"""Guardas de integração 1.0.224; NÃO substituem flutter test/analyze."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def source(path):
    return (ROOT / path).read_text(encoding='utf-8')


class DestinationSearchContracts(unittest.TestCase):
    def test_incremental_search_does_not_call_nominatim(self):
        code = source('lib/services/map_destination_search_service.dart')
        start = code.index('  void updateLocalQuery(')
        end = code.index('  Future<void> searchSubmitted(', start)
        self.assertNotIn('_fetchNominatim(', code[start:end])
        self.assertIn('_searchLocal(', code[start:end])

    def test_nominatim_is_submitted_with_nonrestrictive_regional_preference(self):
        code = source('lib/services/map_destination_search_service.dart')
        part = code[code.index('  Future<List<MapDestinationSearchResult>> _fetchNominatim('):]
        for part_of_api in ("'namedetails': '1'", "'viewbox':", "'bounded': '0'",
                            '_respectNominatimRateLimit()', 'const Duration(hours: 1)'):
            self.assertIn(part_of_api, part)

    def test_local_results_use_same_ranking_and_no_stale_query_overwrite(self):
        code = source('lib/services/map_destination_search_service.dart')
        self.assertGreaterEqual(code.count('MapDestinationRanking.ranked('), 3)
        self.assertIn('if (revision != _searchRevision) return;', code)
        self.assertIn('MapDestinationRanking.repairCachedTitle', code)

    def test_distance_and_sources_are_not_equated_to_driving_route(self):
        ui = source('lib/screens/map_monitoring_screen.dart')
        self.assertIn('em linha reta', ui)
        self.assertIn('resultSection(item, query)', ui)
        self.assertIn('Visualizar rota até o destino', ui)
        self.assertIn("return 'Cache local';", ui)

    def test_pure_dart_regressions_exist(self):
        code = source('test/map_destination_ranking_test.dart')
        self.assertIn('correspondência exata distante', code)
        self.assertIn('homônimos em cidades diferentes', code)
        self.assertIn('cache legado não reapresenta Salvador', code)

if __name__ == '__main__':
    unittest.main()
