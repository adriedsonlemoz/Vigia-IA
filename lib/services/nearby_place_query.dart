import 'dart:math' as math;

/// Gera uma consulta Overpass limitada por caixa geográfica para
/// localizar municípios e comunidades sem pesquisa textual.
/// A seleção circular exata é aplicada após receber os resultados.
class NearbyPlaceQuery {
  const NearbyPlaceQuery._();

  static String build({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required int maximumItems,
    required int queryTimeoutSeconds,
  }) {
    final latDelta = radiusKm / 111.32;
    final cosLat = math.cos(latitude * math.pi / 180).abs();
    final lonDelta = radiusKm / (111.32 * math.max(cosLat, 0.01));
    final south = math.max(-90.0, latitude - latDelta);
    final north = math.min(90.0, latitude + latDelta);
    final west = math.max(-180.0, longitude - lonDelta);
    final east = math.min(180.0, longitude + lonDelta);
    final bbox = '${south.toStringAsFixed(5)},${west.toStringAsFixed(5)},'
        '${north.toStringAsFixed(5)},${east.toStringAsFixed(5)}';
    // Bbox é preferível a around para consultas espaciais no Overpass.
    // nwr inclui centros de relações/áreas, e não apenas nós OSM.
    return '[out:json][timeout:$queryTimeoutSeconds];'
        'nwr($bbox)["place"~"^(city|town|village|hamlet|isolated_dwelling)\$"]'
        '["name"];out center $maximumItems;';
  }
}
