enum MapTravelMode { bicycle, motorcycle, car, walking }

extension MapTravelModeX on MapTravelMode {
  String get storageValue => switch (this) {
        MapTravelMode.bicycle => 'bicycle',
        MapTravelMode.motorcycle => 'motorcycle',
        MapTravelMode.car => 'car',
        MapTravelMode.walking => 'walking',
      };

  String get label => switch (this) {
        MapTravelMode.bicycle => 'Bicicleta',
        MapTravelMode.motorcycle => 'Moto',
        MapTravelMode.car => 'Carro',
        MapTravelMode.walking => 'A pé',
      };

  String get routeLabel => switch (this) {
        MapTravelMode.bicycle => 'bicicleta',
        MapTravelMode.motorcycle => 'moto',
        MapTravelMode.car => 'carro',
        MapTravelMode.walking => 'caminhada',
      };

  String get valhallaCosting => switch (this) {
        MapTravelMode.bicycle => 'bicycle',
        MapTravelMode.motorcycle => 'motorcycle',
        MapTravelMode.car => 'auto',
        MapTravelMode.walking => 'pedestrian',
      };

  static MapTravelMode fromStorage(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    for (final mode in MapTravelMode.values) {
      if (mode.storageValue == normalized) return mode;
    }
    return MapTravelMode.bicycle;
  }
}
