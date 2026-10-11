import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../models/map_cycling_route.dart';
import '../models/map_navigation_target.dart';

/// Armazena somente a última prévia (geometria, destino e manobras) no aparelho.
/// Não armazena tiles nem fornece novo cálculo de rotas offline.
class SavedBikeRoute {
  const SavedBikeRoute({
    required this.target,
    required this.routes,
    required this.selectedIndex,
  });

  final MapNavigationTarget target;
  final List<MapCyclingRoute> routes;
  final int selectedIndex;
}

class SavedBikeRouteService {
  const SavedBikeRouteService();

  Future<File> _file() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}${Platform.pathSeparator}vigia_saved_route.json');
  }

  Future<void> save(SavedBikeRoute value) async {
    if (value.routes.isEmpty || value.routes.any((route) => route.points.length < 2)) {
      throw const FormatException('Rota sem geometria válida');
    }
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(encode(value)), flush: true);
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }

  Future<SavedBikeRoute?> load() async {
    final file = await _file();
    if (!await file.exists()) return null;
    try {
      return decode(jsonDecode(await file.readAsString()));
    } catch (_) {
      return null;
    }
  }

  static Map<String, Object?> encode(SavedBikeRoute saved) => <String, Object?>{
    'schema': 1,
    'savedAt': DateTime.now().toIso8601String(),
    'target': saved.target.toJson(),
    'selected': saved.selectedIndex,
    'routes': [
      for (final route in saved.routes)
        <String, Object?>{
          'distanceMeters': route.distanceMeters,
          'durationSeconds': route.durationSeconds,
          'points': [
            for (final point in route.points)
              [point.latitude, point.longitude],
          ],
          'maneuvers': [
            for (final maneuver in route.maneuvers)
              <String, Object?>{
                'instruction': maneuver.instruction,
                'beginShapeIndex': maneuver.beginShapeIndex,
                'endShapeIndex': maneuver.endShapeIndex,
                'distanceMeters': maneuver.distanceMeters,
                'durationSeconds': maneuver.durationSeconds,
                'type': maneuver.type,
                'streetName': maneuver.streetName,
              },
          ],
        },
    ],
  };

  static SavedBikeRoute decode(Object? source) {
    if (source is! Map) throw const FormatException('Plano inválido');
    final json = Map<String, dynamic>.from(source);
    if (json['schema'] != 1 || json['target'] is! Map || json['routes'] is! List) {
      throw const FormatException('Versão de plano incompatível');
    }
    final routes = <MapCyclingRoute>[];
    for (final raw in json['routes'] as List) {
      if (raw is! Map) throw const FormatException('Rota inválida');
      final route = Map<String, dynamic>.from(raw);
      final rawPoints = route['points'];
      if (rawPoints is! List || rawPoints.length < 2 || rawPoints.length > 100000) {
        throw const FormatException('Geometria inválida');
      }
      final points = <LatLng>[];
      for (final pair in rawPoints) {
        if (pair is! List || pair.length != 2 || pair[0] is! num || pair[1] is! num) {
          throw const FormatException('Coordenada inválida');
        }
        final lat = (pair[0] as num).toDouble();
        final lng = (pair[1] as num).toDouble();
        if (!lat.isFinite || !lng.isFinite || lat.abs() > 90 || lng.abs() > 180) {
          throw const FormatException('Coordenada fora de faixa');
        }
        points.add(LatLng(lat, lng));
      }
      final maneuvers = <MapCyclingManeuver>[];
      for (final rawManeuver in (route['maneuvers'] as List? ?? const [])) {
        if (rawManeuver is! Map) continue;
        final value = Map<String, dynamic>.from(rawManeuver);
        maneuvers.add(MapCyclingManeuver(
          instruction: value['instruction'] as String? ?? '',
          beginShapeIndex: (value['beginShapeIndex'] as num?)?.toInt() ?? 0,
          endShapeIndex: (value['endShapeIndex'] as num?)?.toInt() ?? 0,
          distanceMeters: (value['distanceMeters'] as num?)?.toDouble() ?? 0,
          durationSeconds: (value['durationSeconds'] as num?)?.toDouble() ?? 0,
          type: (value['type'] as num?)?.toInt(),
          streetName: value['streetName'] as String?,
        ));
      }
      routes.add(MapCyclingRoute(
        points: points,
        distanceMeters: (route['distanceMeters'] as num).toDouble(),
        durationSeconds: (route['durationSeconds'] as num).toDouble(),
        maneuvers: maneuvers,
      ));
    }
    if (routes.isEmpty) throw const FormatException('Nenhuma rota salva');
    final selected = (json['selected'] as num?)?.toInt() ?? 0;
    if (selected < 0 || selected >= routes.length) {
      throw const FormatException('Índice de rota inválido');
    }
    return SavedBikeRoute(
      target: MapNavigationTarget.fromJson(
        Map<String, dynamic>.from(json['target'] as Map)),
      routes: routes,
      selectedIndex: selected,
    );
  }
}
