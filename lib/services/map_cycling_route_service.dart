import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';

import '../models/map_cycling_route.dart';

/// Busca uma rota viária para bicicleta. A tela mantém direção direta como
/// fallback quando a rede ou o serviço de roteamento não estiver disponível.
class MapCyclingRouteService {
  MapCyclingRouteService({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  Future<MapCyclingRoute> fetch({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final payload = jsonEncode(<String, Object>{
      'locations': <Map<String, double>>[
        <String, double>{'lat': origin.latitude, 'lon': origin.longitude},
        <String, double>{'lat': destination.latitude, 'lon': destination.longitude},
      ],
      'costing': 'bicycle',
      'units': 'kilometers',
      'directions_options': <String, Object>{'units': 'kilometers'},
    });
    final uri = Uri.https(
      'valhalla1.openstreetmap.de',
      '/route',
      <String, String>{'json': payload},
    );
    final request = await _client.getUrl(uri).timeout(const Duration(seconds: 8));
    request.headers.set(HttpHeaders.userAgentHeader, 'VigiaIA/1.0.134');
    final response = await request.close().timeout(const Duration(seconds: 12));
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Roteamento indisponível (${response.statusCode})');
    }
    final root = jsonDecode(body) as Map<String, dynamic>;
    final trip = root['trip'] as Map<String, dynamic>?;
    final summary = trip?['summary'] as Map<String, dynamic>?;
    final legs = trip?['legs'] as List<dynamic>?;
    if (summary == null || legs == null || legs.isEmpty) {
      throw const FormatException('Resposta de rota incompleta');
    }
    final points = <LatLng>[];
    for (final rawLeg in legs) {
      final leg = rawLeg as Map<String, dynamic>;
      final shape = leg['shape'] as String?;
      if (shape != null && shape.isNotEmpty) points.addAll(_decodePolyline6(shape));
    }
    if (points.length < 2) throw const FormatException('Rota sem geometria');
    return MapCyclingRoute(
      points: List<LatLng>.unmodifiable(points),
      distanceMeters: ((summary['length'] as num?)?.toDouble() ?? 0) * 1000,
      durationSeconds: (summary['time'] as num?)?.toDouble() ?? 0,
    );
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
