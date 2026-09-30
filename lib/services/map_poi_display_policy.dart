import 'dart:math' as math;

import '../models/route_explorer_models.dart';

class MapPoiCluster {
  const MapPoiCluster({
    required this.latitude,
    required this.longitude,
    required this.items,
    required this.category,
  });

  final double latitude;
  final double longitude;
  final List<RouteExplorerResult> items;
  final RouteExplorerCategory category;

  int get count => items.length;
  bool get isCluster => items.length > 1;
  RouteExplorerResult get first => items.first;
}

/// Reduz a poluição visual dos POIs de acordo com o zoom antes de desenhá-los.
///
/// O mapa topográfico já comunica rios/relevo, por isso rios e pontes recebem
/// densidade menor quando a câmera está distante. Pontos essenciais para uma
/// viagem (combustível, saúde, comida e água) têm prioridade.
class MapPoiDisplayPolicy {
  const MapPoiDisplayPolicy._();

  static int maximumVisibleItems(double zoom) {
    if (zoom < 9.5) return 28;
    if (zoom < 11.0) return 40;
    if (zoom < 12.5) return 56;
    if (zoom < 14.0) return 82;
    if (zoom < 15.5) return 110;
    return 160;
  }

  static int maximumRiverBridgeItems(double zoom) {
    if (zoom < 10.5) return 0;
    if (zoom < 12.0) return 5;
    if (zoom < 13.5) return 12;
    if (zoom < 15.0) return 24;
    return 60;
  }

  static double clusterRadiusMeters(double zoom) {
    if (zoom >= 15.8) return 0;
    if (zoom >= 15.0) return 110;
    if (zoom >= 14.0) return 220;
    if (zoom >= 13.0) return 420;
    if (zoom >= 12.0) return 800;
    if (zoom >= 11.0) return 1500;
    if (zoom >= 10.0) return 2800;
    return 5200;
  }

  static List<MapPoiCluster> clusters({
    required Iterable<RouteExplorerResult> items,
    required double zoom,
    String? selectedId,
  }) {
    final source = items.toList(growable: false);
    if (source.isEmpty) return const <MapPoiCluster>[];

    RouteExplorerResult? selected;
    for (final item in source) {
      if (item.id == selectedId) {
        selected = item;
        break;
      }
    }

    final candidates = _densityLimited(
      source.where((item) => item.id != selectedId),
      zoom,
    );
    final radius = clusterRadiusMeters(zoom);
    final result = <MapPoiCluster>[];

    if (radius <= 0) {
      for (final item in candidates) {
        result.add(_single(item));
      }
    } else {
      final buckets = <String, List<RouteExplorerResult>>{};
      for (final item in candidates) {
        final latitudeCell = radius / 111320.0;
        final cosine = math.cos(item.latitude * math.pi / 180).abs();
        final longitudeMeters = 111320.0 * math.max(0.20, cosine);
        final longitudeCell = radius / longitudeMeters;
        final latKey = (item.latitude / latitudeCell).floor();
        final lonKey = (item.longitude / longitudeCell).floor();
        final key = '$latKey:$lonKey';
        buckets.putIfAbsent(key, () => <RouteExplorerResult>[]).add(item);
      }
      for (final bucket in buckets.values) {
        if (bucket.length == 1) {
          result.add(_single(bucket.first));
          continue;
        }
        var latitude = 0.0;
        var longitude = 0.0;
        for (final item in bucket) {
          latitude += item.latitude;
          longitude += item.longitude;
        }
        result.add(
          MapPoiCluster(
            latitude: latitude / bucket.length,
            longitude: longitude / bucket.length,
            items: List<RouteExplorerResult>.unmodifiable(bucket),
            category: _dominantCategory(bucket),
          ),
        );
      }
    }

    if (selected != null) result.add(_single(selected));
    return List<MapPoiCluster>.unmodifiable(result);
  }

  static List<RouteExplorerResult> _densityLimited(
    Iterable<RouteExplorerResult> items,
    double zoom,
  ) {
    final sorted = items.toList()
      ..sort((a, b) {
        final byPriority = _priority(a.category).compareTo(_priority(b.category));
        if (byPriority != 0) return byPriority;
        return a.distanceMeters.compareTo(b.distanceMeters);
      });

    final maxTotal = maximumVisibleItems(zoom);
    final maxRiver = maximumRiverBridgeItems(zoom);
    var riverCount = 0;
    final selected = <RouteExplorerResult>[];
    for (final item in sorted) {
      if (selected.length >= maxTotal) break;
      if (item.category == RouteExplorerCategory.riverBridge) {
        if (riverCount >= maxRiver) continue;
        riverCount++;
      }
      selected.add(item);
    }
    return selected;
  }

  static MapPoiCluster _single(RouteExplorerResult item) => MapPoiCluster(
        latitude: item.latitude,
        longitude: item.longitude,
        items: <RouteExplorerResult>[item],
        category: item.category,
      );

  static RouteExplorerCategory _dominantCategory(
    List<RouteExplorerResult> items,
  ) {
    RouteExplorerCategory best = items.first.category;
    var bestPriority = _priority(best);
    for (final item in items.skip(1)) {
      final priority = _priority(item.category);
      if (priority < bestPriority) {
        best = item.category;
        bestPriority = priority;
      }
    }
    return best;
  }

  static int _priority(RouteExplorerCategory category) => switch (category) {
        RouteExplorerCategory.fuel => 0,
        RouteExplorerCategory.health => 1,
        RouteExplorerCategory.water => 2,
        RouteExplorerCategory.workshop => 3,
        RouteExplorerCategory.camping => 4,
        RouteExplorerCategory.market => 5,
        RouteExplorerCategory.restaurant => 6,
        RouteExplorerCategory.viewpoint => 7,
        RouteExplorerCategory.waterfall => 8,
        RouteExplorerCategory.stop => 9,
        RouteExplorerCategory.riverBridge => 10,
      };
}
