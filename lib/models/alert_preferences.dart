import 'object_filter_catalog.dart';

class AlertOutputs {
  const AlertOutputs({
    this.voice = true,
    this.sound = false,
    this.vibration = true,
    this.androidNotification = true,
  });

  final bool voice;
  final bool sound;
  final bool vibration;
  final bool androidNotification;

  AlertOutputs copyWith({
    bool? voice,
    bool? sound,
    bool? vibration,
    bool? androidNotification,
  }) =>
      AlertOutputs(
        voice: voice ?? this.voice,
        sound: sound ?? this.sound,
        vibration: vibration ?? this.vibration,
        androidNotification: androidNotification ?? this.androidNotification,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'voice': voice,
        'sound': sound,
        'vibration': vibration,
        'androidNotification': androidNotification,
      };

  factory AlertOutputs.fromJson(Map<String, dynamic> json, {bool? legacyVoice}) {
    return AlertOutputs(
      voice: json['voice'] as bool? ?? legacyVoice ?? true,
      sound: json['sound'] as bool? ?? false,
      vibration: json['vibration'] as bool? ?? true,
      androidNotification: json['androidNotification'] as bool? ?? true,
    );
  }
}



class VoiceAlertPreferences {
  const VoiceAlertPreferences({
    this.mutedSlots = const <String>{},
    this.ttsFallbackEnabled = false,
    this.dynamicTtsEnabled = true,
  });

  final Set<String> mutedSlots;
  final bool ttsFallbackEnabled;
  final bool dynamicTtsEnabled;

  bool allowsSlot(String slot) => !mutedSlots.contains(slot);

  VoiceAlertPreferences copyWith({
    Set<String>? mutedSlots,
    bool? ttsFallbackEnabled,
    bool? dynamicTtsEnabled,
  }) =>
      VoiceAlertPreferences(
        mutedSlots: mutedSlots ?? this.mutedSlots,
        ttsFallbackEnabled: ttsFallbackEnabled ?? this.ttsFallbackEnabled,
        dynamicTtsEnabled: dynamicTtsEnabled ?? this.dynamicTtsEnabled,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'mutedSlots': mutedSlots.toList()..sort(),
        'ttsFallbackEnabled': ttsFallbackEnabled,
        'dynamicTtsEnabled': dynamicTtsEnabled,
      };

  factory VoiceAlertPreferences.fromJson(Map<String, dynamic> json) {
    final muted = (json['mutedSlots'] as List?)
            ?.whereType<String>()
            .where((item) => item.trim().isNotEmpty)
            .toSet() ??
        <String>{};
    return VoiceAlertPreferences(
      mutedSlots: Set<String>.unmodifiable(muted),
      ttsFallbackEnabled: json['ttsFallbackEnabled'] as bool? ?? false,
      dynamicTtsEnabled: json['dynamicTtsEnabled'] as bool? ?? true,
    );
  }
}

class AlertMessages {
  const AlertMessages({
    this.person = 'Pessoa detectada.',
    this.vehicle = 'Automóvel detectado.',
    this.animal = 'Animal detectado.',
    this.other = '{objeto} detectado.',
    this.entered = '{objeto} entrou em {area}.',
    this.exited = '{objeto} saiu de {area}.',
    this.cameraObstructed = 'A câmera parece estar obstruída.',
    this.cameraMoved = 'A câmera sofreu uma mudança brusca de enquadramento.',
    this.byObjectAndArea = const <String, String>{},
  });

  final String person;
  final String vehicle;
  final String animal;
  final String other;
  final String entered;
  final String exited;
  final String cameraObstructed;
  final String cameraMoved;
  final Map<String, String> byObjectAndArea;

  AlertMessages copyWith({
    String? person,
    String? vehicle,
    String? animal,
    String? other,
    String? entered,
    String? exited,
    String? cameraObstructed,
    String? cameraMoved,
    Map<String, String>? byObjectAndArea,
  }) =>
      AlertMessages(
        person: person ?? this.person,
        vehicle: vehicle ?? this.vehicle,
        animal: animal ?? this.animal,
        other: other ?? this.other,
        entered: entered ?? this.entered,
        exited: exited ?? this.exited,
        cameraObstructed: cameraObstructed ?? this.cameraObstructed,
        cameraMoved: cameraMoved ?? this.cameraMoved,
        byObjectAndArea: byObjectAndArea ?? this.byObjectAndArea,
      );

  String resolve({
    required String label,
    required String displayLabel,
    String? zoneName,
    String event = 'alert',
  }) {
    if (event == 'cameraObstructed') return cameraObstructed;
    if (event == 'cameraMoved') return cameraMoved;
    final area = (zoneName == null || zoneName.trim().isEmpty) ? 'área monitorada' : zoneName.trim();
    final groupKey = ObjectFilterCatalog.groupKeyForLabel(label);
    final custom = byObjectAndArea['$label|$area'] ??
        byObjectAndArea['$label|*'] ??
        (groupKey == null ? null : byObjectAndArea['$groupKey|$area']) ??
        (groupKey == null ? null : byObjectAndArea['$groupKey|*']);
    final template = custom ?? switch (event) {
      'entered' => entered,
      'exited' => exited,
      _ when label == 'person' => person,
      _ when ObjectFilterCatalog.automobiles.contains(label) => vehicle,
      _ when ObjectFilterCatalog.animals.contains(label) => animal,
      _ => other,
    };
    return template
        .replaceAll('{objeto}', displayLabel)
        .replaceAll('{area}', area)
        .trim();
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'person': person,
        'vehicle': vehicle,
        'animal': animal,
        'other': other,
        'entered': entered,
        'exited': exited,
        'cameraObstructed': cameraObstructed,
        'cameraMoved': cameraMoved,
        'byObjectAndArea': byObjectAndArea,
      };

  factory AlertMessages.fromJson(Map<String, dynamic> json) {
    final custom = (json['byObjectAndArea'] as Map?)?.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ) ??
        const <String, String>{};
    return AlertMessages(
      person: json['person'] as String? ?? 'Pessoa detectada.',
      vehicle: json['vehicle'] as String? ?? 'Automóvel detectado.',
      animal: json['animal'] as String? ?? 'Animal detectado.',
      other: json['other'] as String? ?? '{objeto} detectado.',
      entered: json['entered'] as String? ?? '{objeto} entrou em {area}.',
      exited: json['exited'] as String? ?? '{objeto} saiu de {area}.',
      cameraObstructed: json['cameraObstructed'] as String? ?? 'A câmera parece estar obstruída.',
      cameraMoved: json['cameraMoved'] as String? ?? 'A câmera sofreu uma mudança brusca de enquadramento.',
      byObjectAndArea: Map<String, String>.unmodifiable(custom),
    );
  }

}
