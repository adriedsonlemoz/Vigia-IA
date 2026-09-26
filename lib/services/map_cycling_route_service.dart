import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';

import '../models/map_cycling_route.dart';
import '../models/map_travel_mode.dart';

/// Busca rotas viárias para o perfil de deslocamento escolhido. A tela mantém
/// direção direta como fallback quando a rede ou o serviço de roteamento não
/// estiver disponível. O nome da classe é preservado nesta etapa para reduzir
/// o risco de regressão durante a migração gradual do renderer de navegação.
class MapCyclingRouteService {
  MapCyclingRouteService({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  Future<MapCyclingRoute> fetch({
    required LatLng origin,
    required LatLng destination,
    MapTravelMode travelMode = MapTravelMode.bicycle,
  }) async {
    final routes = await fetchAlternatives(
      origin: origin,
      destination: destination,
      alternativeCount: 0,
      travelMode: travelMode,
    );
    return routes.first;
  }

  Future<List<MapCyclingRoute>> fetchAlternatives({
    required LatLng origin,
    required LatLng destination,
    int alternativeCount = 2,
    MapTravelMode travelMode = MapTravelMode.bicycle,
  }) async {
    final safeAlternativeCount = alternativeCount.clamp(0, 2).toInt();
    final payload = jsonEncode(<String, Object>{
      'locations': <Map<String, double>>[
        <String, double>{'lat': origin.latitude, 'lon': origin.longitude},
        <String, double>{'lat': destination.latitude, 'lon': destination.longitude},
      ],
      'costing': travelMode.valhallaCosting,
      'units': 'km',
      'language': 'pt-PT',
      'alternates': safeAlternativeCount,
    });
    final uri = Uri.https(
      'valhalla1.openstreetmap.de',
      '/route',
      <String, String>{'json': payload},
    );
    final request = await _client.getUrl(uri).timeout(const Duration(seconds: 8));
    request.headers.set(HttpHeaders.userAgentHeader, 'VigiaIA/1.0.154');
    request.headers.set('X-Client-Id', 'com.vigiaia.app');
    final response = await request.close().timeout(const Duration(seconds: 12));
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Roteamento indisponível (${response.statusCode})');
    }
    return parseRoutes(body);
  }

  List<MapCyclingRoute> parseRoutes(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Resposta de rota inválida');
    }
    final root = Map<String, dynamic>.from(decoded);
    final routes = <MapCyclingRoute>[];

    final primaryTrip = root['trip'];
    if (primaryTrip is Map) {
      routes.add(_parseTrip(Map<String, dynamic>.from(primaryTrip)));
    }

    final alternates = root['alternates'];
    if (alternates is List) {
      for (final rawAlternate in alternates) {
        if (rawAlternate is! Map) continue;
        final alternate = Map<String, dynamic>.from(rawAlternate);
        final rawTrip = alternate['trip'];
        if (rawTrip is! Map) continue;
        final route = _parseTrip(Map<String, dynamic>.from(rawTrip));
        if (!_duplicatesExistingRoute(routes, route)) {
          routes.add(route);
        }
      }
    }

    if (routes.isEmpty) {
      throw const FormatException('Resposta de rota incompleta');
    }
    return List<MapCyclingRoute>.unmodifiable(routes);
  }

  MapCyclingRoute _parseTrip(Map<String, dynamic> trip) {
    final summary = trip['summary'] as Map<String, dynamic>?;
    final legs = trip['legs'] as List<dynamic>?;
    if (summary == null || legs == null || legs.isEmpty) {
      throw const FormatException('Resposta de rota incompleta');
    }
    final points = <LatLng>[];
    final maneuvers = <MapCyclingManeuver>[];
    for (final rawLeg in legs) {
      if (rawLeg is! Map) continue;
      final leg = Map<String, dynamic>.from(rawLeg);
      final shape = leg['shape'] as String?;
      if (shape == null || shape.isEmpty) continue;
      final legPoints = _decodePolyline6(shape);
      if (legPoints.isEmpty) continue;

      var shapeOffset = points.length;
      if (points.isNotEmpty && _samePoint(points.last, legPoints.first)) {
        legPoints.removeAt(0);
        shapeOffset -= 1;
      }
      points.addAll(legPoints);

      final rawManeuvers = leg['maneuvers'];
      if (rawManeuvers is List) {
        for (final rawManeuver in rawManeuvers.whereType<Map>()) {
          final maneuver = Map<String, dynamic>.from(rawManeuver);
          final instruction = (maneuver['instruction'] as String?)?.trim();
          if (instruction == null || instruction.isEmpty) continue;
          final streetNames = maneuver['street_names'];
          final streetName = streetNames is List && streetNames.isNotEmpty
              ? streetNames.first.toString()
              : null;
          maneuvers.add(
            MapCyclingManeuver(
              instruction: instruction,
              beginShapeIndex:
                  shapeOffset + ((maneuver['begin_shape_index'] as num?)?.toInt() ?? 0),
              endShapeIndex:
                  shapeOffset + ((maneuver['end_shape_index'] as num?)?.toInt() ?? 0),
              distanceMeters:
                  ((maneuver['length'] as num?)?.toDouble() ?? 0) * 1000,
              durationSeconds: (maneuver['time'] as num?)?.toDouble() ?? 0,
              type: (maneuver['type'] as num?)?.toInt(),
              streetName: streetName,
            ),
          );
        }
      }
    }
    if (points.length < 2) throw const FormatException('Rota sem geometria');
    return MapCyclingRoute(
      points: List<LatLng>.unmodifiable(points),
      distanceMeters: ((summary['length'] as num?)?.toDouble() ?? 0) * 1000,
      durationSeconds: (summary['time'] as num?)?.toDouble() ?? 0,
      maneuvers: List<MapCyclingManeuver>.unmodifiable(maneuvers),
    );
  }

  bool _duplicatesExistingRoute(
    List<MapCyclingRoute> existing,
    MapCyclingRoute candidate,
  ) {
    for (final route in existing) {
      if (route.points.length != candidate.points.length) continue;
      if (!_samePoint(route.points.first, candidate.points.first) ||
          !_samePoint(route.points.last, candidate.points.last)) {
        continue;
      }
      if (route.points.length == 2) return true;
      final midpoint = route.points.length ~/ 2;
      if (_samePoint(route.points[midpoint], candidate.points[midpoint])) {
        return true;
      }
    }
    return false;
  }

  bool _samePoint(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 0.0000001 &&
        (a.longitude - b.longitude).abs() < 0.0000001;
  }

  List<LatLng> _decodePolyline6(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lon = 0;
    while (index < encoded.length) {
      final latValue = _decodeValue(encoded, index);
      index = latValue.$2;
      lat += latValue.$1;
      final lonValue = _decodeValue(encoded, index);
      index = lonValue.$2;
      lon += lonValue.$1;
      points.add(LatLng(lat / 1e6, lon / 1e6));
    }
    return points;
  }

  (int, int) _decodeValue(String encoded, int start) {
    var result = 0;
    var shift = 0;
    var index = start;
    int byte;
    do {
      if (index >= encoded.length) throw const FormatException('Polyline inválida');
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    final value = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
    return (value, index);
  }
}
