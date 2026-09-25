import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class MapCameraSlotLayout {
  const MapCameraSlotLayout({
    this.xFraction = 0,
    this.yFraction = 0,
    this.sizeScale = 1,
    this.minimized = false,
    this.hidden = false,
  });

  final double xFraction;
  final double yFraction;
  final double sizeScale;
  final bool minimized;
  final bool hidden;

  MapCameraSlotLayout copyWith({
    double? xFraction,
    double? yFraction,
    double? sizeScale,
    bool? minimized,
    bool? hidden,
  }) =>
      MapCameraSlotLayout(
        xFraction: xFraction ?? this.xFraction,
        yFraction: yFraction ?? this.yFraction,
        sizeScale: sizeScale ?? this.sizeScale,
        minimized: minimized ?? this.minimized,
        hidden: hidden ?? this.hidden,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'xFraction': xFraction,
        'yFraction': yFraction,
        'sizeScale': sizeScale,
        'minimized': minimized,
        'hidden': hidden,
      };

  factory MapCameraSlotLayout.fromJson(Map<String, dynamic> json) {
    double readDouble(String key, double fallback) {
      final value = json[key];
      return value is num ? value.toDouble() : fallback;
    }

    return MapCameraSlotLayout(
      xFraction: readDouble('xFraction', 0).clamp(0, 1).toDouble(),
      yFraction: readDouble('yFraction', 0).clamp(0, 1).toDouble(),
      sizeScale: readDouble('sizeScale', 1).clamp(0.72, 1.35).toDouble(),
      minimized: json['minimized'] as bool? ?? false,
      hidden: json['hidden'] as bool? ?? false,
    );
  }
}

class MapCameraOverlaySettingsService {
  MapCameraOverlaySettingsService._();

  static final MapCameraOverlaySettingsService instance =
      MapCameraOverlaySettingsService._();

  File? _file;
  bool _initialized = false;
  MapCameraSlotLayout _primary = const MapCameraSlotLayout(yFraction: 0.08);
  MapCameraSlotLayout _secondary = const MapCameraSlotLayout(
    xFraction: 0,
    yFraction: 0.78,
  );

  MapCameraSlotLayout get primary => _primary;
  MapCameraSlotLayout get secondary => _secondary;

  Future<void> initialize() async {
    if (_initialized) return;
    final root = await getApplicationSupportDirectory();
    _file = File(
      '${root.path}${Platform.pathSeparator}map_camera_overlay_settings.json',
    );
    final file = _file;
    if (file != null && await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          final map = decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          );
          final primary = map['primary'];
          final secondary = map['secondary'];
          if (primary is Map) {
            _primary = MapCameraSlotLayout.fromJson(
              primary.map((key, value) => MapEntry(key.toString(), value)),
            );
          }
          if (secondary is Map) {
            _secondary = MapCameraSlotLayout.fromJson(
              secondary.map((key, value) => MapEntry(key.toString(), value)),
            );
          }
        }
      } catch (_) {
        // Configuração visual corrompida não deve impedir a abertura do mapa.
      }
    }
    _initialized = true;
  }

  Future<void> savePrimary(MapCameraSlotLayout value) async {
    await initialize();
    _primary = value;
    await _persist();
  }

  Future<void> saveSecondary(MapCameraSlotLayout value) async {
    await initialize();
    _secondary = value;
    await _persist();
  }

  Future<void> resetLayout() async {
    await initialize();
    _primary = const MapCameraSlotLayout(yFraction: 0.08);
    _secondary = const MapCameraSlotLayout(
      xFraction: 0,
      yFraction: 0.78,
    );
    await _persist();
  }

  Future<void> _persist() async {
    final file = _file;
    if (file == null) return;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'schema': 1,
        'primary': _primary.toJson(),
        'secondary': _secondary.toJson(),
      }),
      flush: true,
    );
  }
}
