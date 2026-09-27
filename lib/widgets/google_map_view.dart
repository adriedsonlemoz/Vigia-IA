import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart';

/// Adapter visual do Google Maps. Mantém o mapa Google isolado do domínio do
/// Vigia IA: pontos e rotas continuam pertencendo à tela principal.
class GoogleMapView extends StatelessWidget {
  const GoogleMapView({
    super.key,
    required this.initialCenter,
    required this.initialZoom,
    required this.mapType,
    required this.markers,
    required this.polylines,
    required this.onMapCreated,
    required this.onCameraMove,
    required this.onCameraMoveStarted,
    required this.onTap,
    required this.onLongPress,
  });

  final LatLng initialCenter;
  final double initialZoom;
  final gmaps.MapType mapType;
  final Set<gmaps.Marker> markers;
  final Set<gmaps.Polyline> polylines;
  final ValueChanged<gmaps.GoogleMapController> onMapCreated;
  final ValueChanged<gmaps.CameraPosition> onCameraMove;
  final VoidCallback onCameraMoveStarted;
  final ValueChanged<LatLng> onTap;
  final ValueChanged<LatLng> onLongPress;

  @override
  Widget build(BuildContext context) {
    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: gmaps.LatLng(initialCenter.latitude, initialCenter.longitude),
        zoom: initialZoom,
      ),
      mapType: mapType,
      markers: markers,
      polylines: polylines,
      minMaxZoomPreference: const gmaps.MinMaxZoomPreference(3, 20),
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      rotateGesturesEnabled: true,
      tiltGesturesEnabled: true,
      onMapCreated: onMapCreated,
      onCameraMoveStarted: onCameraMoveStarted,
      onCameraMove: onCameraMove,
      onTap: (point) => onTap(LatLng(point.latitude, point.longitude)),
      onLongPress: (point) => onLongPress(LatLng(point.latitude, point.longitude)),
    );
  }
}
