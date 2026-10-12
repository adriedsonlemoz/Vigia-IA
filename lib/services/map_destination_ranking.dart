import 'dart:math' as math;

import '../models/map_destination_search.dart';

/// Relevância e identidade de destinos, sem dependência de rede ou estado UI.
/// Distâncias recebidas representam linha reta, nunca percurso rodoviário.
class MapDestinationRanking {
  const MapDestinationRanking._();

  /// O nome do próprio objeto OSM prevalece sobre os campos administrativos.
  /// Nominatim pode devolver cidade/município como contexto de um logradouro.
  static String canonicalTitle(Map<String, dynamic> item) {
    String nonEmpty(Object? value) => value is String ? value.trim() : '';

    final ownName = nonEmpty(item['name']);
    if (ownName.isNotEmpty) return ownName;
    final named = item['namedetails'];
    if (named is Map) {
      for (final key in const <String>['name:pt-BR', 'name:pt', 'name', 'name:en']) {
        final value = nonEmpty(named[key]);
        if (value.isNotEmpty) return value;
      }
    }
    final address = item['address'];
    if (address is Map) {
      final value = nonEmpty(address['name']);
      if (value.isNotEmpty) return value;
    }
    final display = nonEmpty(item['display_name']);
    if (display.isNotEmpty) {
      final first = display.split(',').first.trim();
      if (first.isNotEmpty) return first;
    }
    if (address is Map) {
      for (final key in const <String>[
        'road', 'amenity', 'shop', 'tourism', 'city', 'town',
        'village', 'hamlet', 'municipality',
      ]) {
        final value = nonEmpty(address[key]);
        if (value.isNotEmpty) return value;
      }
    }
    return 'Local sem nome';
  }

  /// Corrige títulos herdados do decodificador anterior, que preferia
  /// city/town ao nome do objeto Nominatim. Não altera identificadores OSM.
  static MapDestinationSearchResult repairCachedTitle(
    MapDestinationSearchResult item,
  ) {
    if (!item.id.startsWith('nominatim:') &&
        !item.id.startsWith('reverse:')) return item;
    final first = item.subtitle.split(',').first.trim();
    if (first.isEmpty || first.length < 2 ||
        first.contains(' · ') || fold(first) == fold(item.title)) {
      return item;
    }
    return item.copyWith(title: first);
  }

  static String fold(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[áàâãä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[íìîï]'), 'i')
      .replaceAll(RegExp(r'[óòôõö]'), 'o')
      .replaceAll(RegExp(r'[úùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static int relevance(MapDestinationSearchResult item, String query) {
    final needle = fold(query.split(',').first);
    if (needle.isEmpty) return 0;
    final title = fold(item.title);
    final subtitle = fold(item.subtitle);
    final terms = needle.split(' ').where((s) => s.isNotEmpty).toList();
    var score = 0;
    if (title == needle) {
      score = 1200;
    } else if (title.startsWith('$needle ')) {
      score = 980;
    } else if (title.startsWith(needle)) {
      score = 900;
    } else if (title.contains(needle)) {
      score = 780;
    } else if (terms.every(title.contains)) {
      score = 660;
    } else if (terms.any((term) => title.contains(term))) {
      score = 260;
    } else if (subtitle.contains(needle) || terms.every(subtitle.contains)) {
      // Município/UF é contexto, não prova de que o objeto tenha esse nome.
      score = 90;
    }
    if (item.kind != MapDestinationKind.pointOfInterest &&
        item.kind != MapDestinationKind.place) {
      score += 70;
    }
    if (item.offline) score += 25;
    if (item.source == 'cache') score += 10;
    // Viés regional moderado: nome exato remoto supera título parcial local.
    if (item.distanceMeters <= 90000) score += 45;
    if (item.distanceMeters <= 15000) score += 15;
    return score;
  }

  static List<MapDestinationSearchResult> ranked(
    Iterable<MapDestinationSearchResult> items,
    String query, {
    int? limit,
  }) {
    final values = deduplicate(items).toList(growable: true)
      ..sort((a, b) {
        final byName = relevance(b, query).compareTo(relevance(a, query));
        if (byName != 0) return byName;
        final byDistance = a.distanceMeters.compareTo(b.distanceMeters);
        return byDistance != 0 ? byDistance : a.title.compareTo(b.title);
      });
    return limit == null ? values : values.take(limit).toList(growable: false);
  }

  /// Não funde homônimos de cidades distantes. Identidade OSM e coordenadas
  /// próximas resolvem duplicatas provenientes de cache, Overpass e Nominatim.
  static List<MapDestinationSearchResult> deduplicate(
    Iterable<MapDestinationSearchResult> items,
  ) {
    final result = <MapDestinationSearchResult>[];
    for (final item in items) {
      final osmId = _osmKey(item.id);
      var existingIndex = -1;
      for (var index = 0; index < result.length; index++) {
        final other = result[index];
        final otherId = _osmKey(other.id);
        final sameOsm = osmId != null && osmId == otherId;
        final sameNamedLocation = fold(item.title) == fold(other.title) &&
            _straightMeters(item.latitude, item.longitude,
                other.latitude, other.longitude) <= 85;
        if (sameOsm || sameNamedLocation) {
          existingIndex = index;
          break;
        }
      }
      if (existingIndex < 0) {
        result.add(item);
      } else {
        final old = result[existingIndex];
        final sameOsm = _osmKey(item.id) != null &&
            _osmKey(item.id) == _osmKey(old.id);
        final newerCanonical = sameOsm && item.source == 'online' &&
            old.source == 'cache' && fold(item.title) != fold(old.title);
        if (newerCanonical || _priority(item) > _priority(old) ||
            (_priority(item) == _priority(old) &&
                item.subtitle.length > old.subtitle.length)) {
          result[existingIndex] = item;
        }
      }
    }
    return result;
  }

  static int _priority(MapDestinationSearchResult item) => switch (item.source) {
        'offline' => 3,
        'cache' => 2,
        'online' => 1,
        _ => 0,
      };

  static String? _osmKey(String id) {
    final pieces = id.split(':');
    if (pieces.length < 3) return null;
    final type = pieces[pieces.length - 2].toLowerCase();
    final number = pieces.last;
    if (!const <String>{'node', 'way', 'relation', 'n', 'w', 'r'}.contains(type) ||
        int.tryParse(number) == null) return null;
    final normalized = switch (type) {
      'n' => 'node',
      'w' => 'way',
      'r' => 'relation',
      _ => type,
    };
    return '$normalized:$number';
  }

  static double _straightMeters(double aLat, double aLon, double bLat, double bLon) {
    const radius = 6371000.0;
    final latDelta = (bLat - aLat) * math.pi / 180;
    final lonDelta = (bLon - aLon) * math.pi / 180;
    final middle = math.pow(math.sin(latDelta / 2), 2) +
        math.cos(aLat * math.pi / 180) *
        math.cos(bLat * math.pi / 180) *
        math.pow(math.sin(lonDelta / 2), 2);
    return radius * 2 * math.asin(math.sqrt(middle.clamp(0.0, 1.0)));
  }
}
