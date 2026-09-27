import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';

/// Sobreposição opcional de vias cuja superfície está marcada no OSM.
/// Não infere asfalto/terra de vias sem tag surface.
class MapSurfaceSegment {
  const MapSurfaceSegment(this.points, this.kind);
  final List<LatLng> points;
  final String kind;
}

class MapRoadOverlayService {
  MapRoadOverlayService({HttpClient? client}) : _client = client ?? HttpClient();
  final HttpClient _client;
  DateTime? _fetchedAt;
  DateTime? _lastAttemptAt;
  LatLng? _center;
  List<MapSurfaceSegment> _cached = const <MapSurfaceSegment>[];

  void dispose() => _client.close(force: true);

  static String? classify(Map<String, String> tags) {
    if (tags['waterway'] == 'river' || tags['waterway'] == 'stream') return 'water';
    final surface = tags['surface']?.toLowerCase();
    if (<String>{'unpaved','gravel','ground','dirt','earth','sand','mud',
        'grass','fine_gravel','compacted','pebblestone'}.contains(surface)) return 'earth';
    if (<String>{'motorway','trunk','primary'}.contains(tags['highway'])) {
      return 'highway';
    }
    if (<String>{'asphalt','paved','concrete','concrete:plates','paving_stones'}
        .contains(surface)) return 'asphalt';
    return null;
  }

  Future<List<MapSurfaceSegment>> near(LatLng point) async {
    final now = DateTime.now();
    final previous = _center;
    if (_fetchedAt != null && previous != null &&
        DateTime.now().difference(_fetchedAt!) < const Duration(minutes: 12) &&
        const Distance().as(LengthUnit.Meter, point, previous) < 1200) {
      return _cached;
    }
    if (_lastAttemptAt != null &&
        now.difference(_lastAttemptAt!) < const Duration(seconds: 30)) {
      return _cached;
    }
    _lastAttemptAt = now;
    const radius = 2500;
    final query = '[out:json][timeout:12];('
        'way(around:$radius,${point.latitude},${point.longitude})["highway"]["surface"];'
        'way(around:$radius,${point.latitude},${point.longitude})["highway"~"motorway|trunk|primary"];'
        'way(around:$radius,${point.latitude},${point.longitude})["waterway"~"river|stream"];'
        ');out geom 350;';
    final request = await _client.postUrl(Uri.parse('https://overpass-api.de/api/interpreter'))
        .timeout(const Duration(seconds: 7));
    request.headers.set(HttpHeaders.userAgentHeader, 'VigiaIA/1.0.193 road-overlay');
    request.headers.contentType = ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
    request.write('data=${Uri.encodeQueryComponent(query)}');
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException('Overpass ${response.statusCode}');
    }
    final body = await utf8.decoder.bind(response).join().timeout(const Duration(seconds: 8));
    final decoded = jsonDecode(body);
    final segments = <MapSurfaceSegment>[];
    if (decoded is Map && decoded['elements'] is List) {
      for (final raw in (decoded['elements'] as List).whereType<Map>()) {
        final rawTags = raw['tags'];
        final rawGeometry = raw['geometry'];
        if (rawTags is! Map || rawGeometry is! List) continue;
        final tags = rawTags.map((key, value) => MapEntry(key.toString(), value.toString()));
        final kind = classify(tags);
        if (kind == null) continue;
        final points = <LatLng>[];
        for (final coordinate in rawGeometry.whereType<Map>()) {
          final lat = (coordinate['lat'] as num?)?.toDouble();
          final lon = (coordinate['lon'] as num?)?.toDouble();
          if (lat != null && lon != null) points.add(LatLng(lat, lon));
        }
        if (points.length >= 2) segments.add(MapSurfaceSegment(points, kind));
      }
    }
    _cached = List<MapSurfaceSegment>.unmodifiable(segments);
    _center = point;
    _fetchedAt = DateTime.now();
    return _cached;
  }
}
