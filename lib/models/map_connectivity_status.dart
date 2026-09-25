enum MapConnectivityState {
  unknown,
  online,
  offline,
}

extension MapConnectivityStateX on MapConnectivityState {
  bool get isOnline => this == MapConnectivityState.online;
  bool get isOffline => this == MapConnectivityState.offline;

  String get label => switch (this) {
        MapConnectivityState.unknown => 'Verificando conexão',
        MapConnectivityState.online => 'Online',
        MapConnectivityState.offline => 'Sem internet',
      };
}
