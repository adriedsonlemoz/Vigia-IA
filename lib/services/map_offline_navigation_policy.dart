class MapRouteFallbackDecision {
  const MapRouteFallbackDecision({
    required this.keepKnownRoute,
    required this.message,
  });

  final bool keepKnownRoute;
  final String message;
}

class MapOfflineNavigationPolicy {
  const MapOfflineNavigationPolicy._();

  static MapRouteFallbackDecision routeFailure({
    required bool hasKnownRoute,
    required bool networkOffline,
    required bool recalculation,
  }) {
    if (hasKnownRoute) {
      if (networkOffline) {
        return const MapRouteFallbackDecision(
          keepKnownRoute: true,
          message:
              'Sem internet. Mantendo a última rota conhecida até a conexão voltar.',
        );
      }
      return MapRouteFallbackDecision(
        keepKnownRoute: true,
        message: recalculation
            ? 'Não foi possível recalcular agora. Mantendo a última rota conhecida.'
            : 'Serviço de rota indisponível. Mantendo a última rota conhecida.',
      );
    }

    return MapRouteFallbackDecision(
      keepKnownRoute: false,
      message: networkOffline
          ? 'Sem internet e sem rota viária disponível. Mostrando apenas a direção do destino.'
          : 'Rota viária indisponível. Mostrando apenas a direção do destino.',
    );
  }
}
