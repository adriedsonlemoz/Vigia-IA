"""Contratos preventivos de cobertura offline e sondagens 1.0.231."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]


def violations(coverage: str, screen: str, network: str, recovery: str, manager: str, tests: str) -> list[str]:
    checks = {
        'cobertura desconhecida': 'OfflineMapCoverageState.unknown' in coverage,
        'corredor sem garantia': "package.downloadKind == 'route'" in coverage,
        'zoom com detalhe limitado': 'OfflineMapCoverageState.outsideZoom' in coverage,
        'avisos vinculados ao HUD': 'OfflineMapCoveragePolicy.needsWarning(offlineCoverage)' in screen and 'status: offlineCoverage' in screen,
        'gerenciador explica corredor': 'somente o corredor baixado' in manager,
        'legado sem limites': 'Área desconhecida: confira o mapa' in manager,
        'rede usa intervalo offline maior': 'offlineProbeInterval = const Duration(seconds: 60)' in network and 'currentPollingInterval' in network,
        'rede reinicia timer quando muda': '_restartPolling();\n      notifyListeners();' in network,
        'sem consulta DNS duplicada': 'checkNow(force: true)' not in recovery and '_connectivity.isOffline' in recovery,
        'recuperacao com listener online': '_recoverNavigationAfterConnection()' in recovery and '_connectivity.isOnline' in recovery,
        'testes reais de regras': 'OfflineMapCoverageState.corridorUnverified' in tests,
    }
    return [name for name, ok in checks.items() if not ok]


def main() -> None:
    read = lambda path: (ROOT / path).read_text(encoding='utf-8')
    missing = violations(
        read('lib/services/offline_map_coverage_policy.dart'),
        read('lib/screens/map_monitoring_screen.dart'),
        read('lib/services/map_connectivity_service.dart'),
        read('lib/screens/map_monitoring_offline_support.dart'),
        read('lib/widgets/offline_map_manager_sheet.dart'),
        read('test/offline_map_coverage_policy_test.dart'),
    )
    if missing:
        raise SystemExit('Falha contratos offline/autonomia: ' + ', '.join(missing))
    print('11 contratos offline e autonomia 1.0.231 aprovados')

if __name__ == '__main__':
    main()
