import '../models/route_explorer_models.dart';

class RouteExplorerPoiMetadata {
  const RouteExplorerPoiMetadata({
    required this.category,
    required this.title,
    required this.subtitle,
    this.address,
    this.openingHours,
    this.phone,
    this.website,
    this.operatorName,
    this.amenities = const <String>[],
  });

  final RouteExplorerCategory category;
  final String title;
  final String subtitle;
  final String? address;
  final String? openingHours;
  final String? phone;
  final String? website;
  final String? operatorName;
  final List<String> amenities;
}

/// Catálogo central de POIs do mapa.
///
/// Mantém as regras de consulta e a leitura das tags do OpenStreetMap fora da
/// tela e do serviço de rede, facilitando evolução e testes sem inflar o mapa.
class RouteExplorerPoiCatalog {
  const RouteExplorerPoiCatalog._();

  static List<String> clausesFor(RouteExplorerCategory category) {
    switch (category) {
      case RouteExplorerCategory.fuel:
        return const <String>['["amenity"="fuel"]'];
      case RouteExplorerCategory.restaurant:
        return const <String>[
          '["amenity"="restaurant"]',
          '["amenity"="fast_food"]',
          '["amenity"="cafe"]',
        ];
      case RouteExplorerCategory.stop:
        return const <String>[
          '["amenity"="parking"]',
          '["amenity"="shelter"]',
          '["amenity"="bus_station"]',
        ];
      case RouteExplorerCategory.workshop:
        return const <String>[
          '["shop"="car_repair"]',
          '["shop"="bicycle"]',
          '["amenity"="bicycle_repair_station"]',
        ];
      case RouteExplorerCategory.health:
        return const <String>[
          '["amenity"="pharmacy"]',
          '["amenity"="hospital"]',
          '["amenity"="clinic"]',
          '["amenity"="doctors"]',
        ];
      case RouteExplorerCategory.water:
        return const <String>[
          '["amenity"="drinking_water"]',
          '["amenity"="toilets"]',
          '["amenity"="shower"]',
        ];
      case RouteExplorerCategory.camping:
        return const <String>[
          '["tourism"="camp_site"]',
          '["tourism"="caravan_site"]',
        ];
      case RouteExplorerCategory.viewpoint:
        return const <String>['["tourism"="viewpoint"]'];
      case RouteExplorerCategory.waterfall:
        return const <String>[
          '["natural"="waterfall"]',
          '["waterway"="waterfall"]',
        ];
      case RouteExplorerCategory.market:
        return const <String>[
          '["shop"="supermarket"]',
          '["shop"="convenience"]',
          '["shop"="grocery"]',
          '["shop"="greengrocer"]',
        ];
      case RouteExplorerCategory.riverBridge:
        return const <String>[
          '["waterway"="river"]',
          '["waterway"="stream"]',
          '["bridge"]',
          '["man_made"="bridge"]',
        ];
    }
  }

  static RouteExplorerCategory? resolveCategory(Map<String, String> tags) {
    final amenity = tags['amenity'];
    final tourism = tags['tourism'];
    final shop = tags['shop'];
    final natural = tags['natural'];
    final waterway = tags['waterway'];
    final manMade = tags['man_made'];
    final bridge = tags['bridge'];

    if (amenity == 'fuel') return RouteExplorerCategory.fuel;
    if (amenity == 'restaurant' || amenity == 'fast_food' || amenity == 'cafe') {
      return RouteExplorerCategory.restaurant;
    }
    if (tourism == 'camp_site' || tourism == 'caravan_site') {
      return RouteExplorerCategory.camping;
    }
    if (tourism == 'viewpoint') return RouteExplorerCategory.viewpoint;
    if (natural == 'waterfall' || waterway == 'waterfall') {
      return RouteExplorerCategory.waterfall;
    }
    if (shop == 'supermarket' ||
        shop == 'convenience' ||
        shop == 'grocery' ||
        shop == 'greengrocer') {
      return RouteExplorerCategory.market;
    }
    if (amenity == 'parking' ||
        amenity == 'shelter' ||
        amenity == 'bus_station') {
      return RouteExplorerCategory.stop;
    }
    if (shop == 'car_repair' ||
        shop == 'bicycle' ||
        amenity == 'bicycle_repair_station') {
      return RouteExplorerCategory.workshop;
    }
    if (amenity == 'pharmacy' ||
        amenity == 'hospital' ||
        amenity == 'clinic' ||
        amenity == 'doctors') {
      return RouteExplorerCategory.health;
    }
    if (amenity == 'drinking_water' || amenity == 'toilets' || amenity == 'shower') {
      return RouteExplorerCategory.water;
    }
    if (waterway == 'river' ||
        waterway == 'stream' ||
        manMade == 'bridge' ||
        (bridge != null && bridge.isNotEmpty)) {
      return RouteExplorerCategory.riverBridge;
    }
    return null;
  }

  static RouteExplorerPoiMetadata? metadataFor(Map<String, String> tags) {
    final category = resolveCategory(tags);
    if (category == null) return null;

    final address = _address(tags);
    final openingHours = _text(tags['opening_hours']);
    final phone = _text(tags['contact:phone']) ?? _text(tags['phone']);
    final website = _text(tags['contact:website']) ?? _text(tags['website']);
    final operatorName = _text(tags['operator']) ?? _text(tags['brand']);
    final amenities = _amenities(tags);

    return RouteExplorerPoiMetadata(
      category: category,
      title: _title(category, tags),
      subtitle: _subtitle(
        category,
        tags,
        address: address,
        operatorName: operatorName,
      ),
      address: address,
      openingHours: openingHours,
      phone: phone,
      website: website,
      operatorName: operatorName,
      amenities: amenities,
    );
  }

  static String _title(
    RouteExplorerCategory category,
    Map<String, String> tags,
  ) {
    final name = _text(tags['name']);
    if (name != null) return name;
    return switch (category) {
      RouteExplorerCategory.fuel => 'Posto próximo',
      RouteExplorerCategory.restaurant => 'Restaurante próximo',
      RouteExplorerCategory.stop => 'Parada próxima',
      RouteExplorerCategory.workshop => 'Oficina próxima',
      RouteExplorerCategory.health => 'Ponto de saúde',
      RouteExplorerCategory.water => 'Água/banheiro',
      RouteExplorerCategory.camping => 'Camping próximo',
      RouteExplorerCategory.viewpoint => 'Mirante próximo',
      RouteExplorerCategory.waterfall => 'Cachoeira próxima',
      RouteExplorerCategory.market => 'Mercado próximo',
      RouteExplorerCategory.riverBridge => 'Rio ou ponte',
    };
  }

  static String _subtitle(
    RouteExplorerCategory category,
    Map<String, String> tags, {
    required String? address,
    required String? operatorName,
  }) {
    final details = <String>[];
    details.add(
      switch (category) {
        RouteExplorerCategory.fuel => 'Combustível',
        RouteExplorerCategory.restaurant => 'Alimentação',
        RouteExplorerCategory.stop => 'Parada',
        RouteExplorerCategory.workshop => 'Suporte mecânico',
        RouteExplorerCategory.health => 'Atendimento',
        RouteExplorerCategory.water => 'Água ou banheiro',
        RouteExplorerCategory.camping => 'Pernoite/camping',
        RouteExplorerCategory.viewpoint => 'Ponto panorâmico',
        RouteExplorerCategory.waterfall => 'Atrativo natural',
        RouteExplorerCategory.market => 'Mantimentos',
        RouteExplorerCategory.riverBridge => 'Referência no caminho',
      },
    );

    final ref = _text(tags['ref']);
    final description = _text(tags['description']);
    if (operatorName != null) details.add(operatorName);
    if (ref != null) details.add(ref);
    if (address != null) details.add(address);
    if (description != null) details.add(description);
    return details.toSet().join(' · ');
  }

  static String? _address(Map<String, String> tags) {
    final full = _text(tags['addr:full']);
    if (full != null) return full;
    final street = _text(tags['addr:street']);
    final number = _text(tags['addr:housenumber']);
    final city = _text(tags['addr:city']);
    final pieces = <String>[];
    if (street != null && number != null) {
      pieces.add('$street, $number');
    } else if (street != null) {
      pieces.add(street);
    }
    if (city != null) pieces.add(city);
    return pieces.isEmpty ? null : pieces.join(' · ');
  }

  static List<String> _amenities(Map<String, String> tags) {
    final items = <String>[];
    void addWhen(String key, String label) {
      final value = tags[key]?.toLowerCase();
      if (value == 'yes' || value == 'designated' || value == 'customers') {
        items.add(label);
      }
    }

    addWhen('drinking_water', 'Água potável');
    addWhen('toilets', 'Banheiro');
    addWhen('shower', 'Chuveiro');
    addWhen('bicycle_parking', 'Bicicletário');
    addWhen('service:bicycle:pump', 'Bomba para bicicleta');
    addWhen('service:bicycle:tools', 'Ferramentas para bicicleta');
    addWhen('power_supply', 'Energia elétrica');

    final amenity = tags['amenity'];
    if (amenity == 'drinking_water') items.add('Água potável');
    if (amenity == 'toilets') items.add('Banheiro');
    if (amenity == 'shower') items.add('Chuveiro');
    if (amenity == 'bicycle_repair_station') items.add('Estação de reparo');
    final internet = tags['internet_access']?.toLowerCase();
    if (internet == 'yes' || internet == 'wlan' || internet == 'wifi') {
      items.add('Internet');
    }

    final fee = tags['fee']?.toLowerCase();
    if (fee == 'no') items.add('Gratuito');
    if (fee == 'yes') items.add('Pago');

    final capacity = _text(tags['capacity']);
    if (capacity != null &&
        (tags['tourism'] == 'camp_site' || tags['tourism'] == 'caravan_site')) {
      items.add('Capacidade $capacity');
    }
    return items.toSet().toList(growable: false);
  }

  static String? _text(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
