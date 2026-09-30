import '../models/route_explorer_models.dart';

class RouteExplorerAlertCandidate {
  const RouteExplorerAlertCandidate({
    required this.item,
    required this.thresholdMeters,
    required this.consumedThresholds,
  });

  final RouteExplorerResult item;
  final int thresholdMeters;
  final Set<int> consumedThresholds;
}

/// Decide qual POI pode gerar o próximo aviso sem conhecer UI, rede ou áudio.
class RouteExplorerAlertPolicy {
  const RouteExplorerAlertPolicy();

  static const Duration minimumInterval = Duration(minutes: 1);
  static const int finalApproachDistanceMeters = 1000;

  RouteExplorerAlertCandidate? select({
    required List<RouteExplorerResult> results,
    required RouteExplorerSettings settings,
    required Map<String, Set<int>> deliveredThresholds,
    required DateTime now,
    DateTime? lastDeliveredAt,
    bool Function(RouteExplorerResult item)? directionFilter,
  }) {
    if (!settings.alertsEnabled || results.isEmpty) return null;
    if (lastDeliveredAt != null &&
        now.difference(lastDeliveredAt) < minimumInterval) {
      return null;
    }

    final thresholds = <int>{
      settings.alertDistanceMeters,
      finalApproachDistanceMeters,
    }.toList()
      ..sort();

    for (final item in results) {
      if (!settings.categories.contains(item.category)) continue;
      if (directionFilter != null && !directionFilter(item)) continue;
      final delivered = deliveredThresholds[item.id] ?? const <int>{};
      for (final threshold in thresholds) {
        if (item.distanceMeters <= threshold && !delivered.contains(threshold)) {
          return RouteExplorerAlertCandidate(
            item: item,
            thresholdMeters: threshold,
            consumedThresholds: thresholds
                .where((candidate) => candidate >= threshold)
                .toSet(),
          );
        }
      }
    }
    return null;
  }
}
