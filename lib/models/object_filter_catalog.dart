class ObjectFilterCatalog {
  const ObjectFilterCatalog._();

  /// Classes do modelo que representam pessoas.
  static const Set<String> people = <String>{'person'};

  /// Automóveis expostos ao usuário. Bicicleta, trem, avião e barco não fazem
  /// parte deste grupo porque a interface trabalha somente com automóveis.
  static const Set<String> automobiles = <String>{
    'car',
    'motorcycle',
    'bus',
    'truck',
  };

  /// Alias mantido para regras internas e compatibilidade com código antigo.
  static const Set<String> vehicles = automobiles;

  /// Animais úteis para monitoramento residencial/rural reconhecidos pelo
  /// modelo atual. Classes exóticas continuam no labelmap do TensorFlow, mas
  /// não são expostas nem aceitas pelo filtro visual.
  static const Set<String> animals = <String>{
    'bird',
    'cat',
    'dog',
    'horse',
    'sheep',
    'cow',
  };

  static const Set<String> recommended = <String>{
    ...people,
    ...automobiles,
    ...animals,
  };

  /// Rótulos antigos usados para migrar preferências sem quebrar atualizações.
  static const Set<String> legacyVehicleLabels = <String>{
    'bicycle',
    'car',
    'motorcycle',
    'airplane',
    'bus',
    'train',
    'truck',
    'boat',
  };

  static const Set<String> legacyAnimalLabels = <String>{
    'bird',
    'cat',
    'dog',
    'horse',
    'sheep',
    'cow',
    'elephant',
    'bear',
    'zebra',
    'giraffe',
  };

  /// Mantido por compatibilidade. Visualmente o aplicativo só trabalha com
  /// os rótulos monitoráveis abaixo.
  static const List<String> allLabels = <String>[
    'person',
    'car',
    'motorcycle',
    'bus',
    'truck',
    'bird',
    'cat',
    'dog',
    'horse',
    'sheep',
    'cow',
  ];

  static Set<String> normalizeSelection(Iterable<String> labels) {
    final legacy = labels.toSet();
    final normalized = <String>{};

    if (legacy.any(people.contains)) normalized.addAll(people);
    if (legacy.any(legacyVehicleLabels.contains)) {
      normalized.addAll(automobiles);
    }
    if (legacy.any(legacyAnimalLabels.contains)) normalized.addAll(animals);

    // Preferências antigas que continham apenas objetos agora ocultos não
    // deixam o monitor silencioso após a atualização.
    if (normalized.isEmpty && legacy.isNotEmpty) {
      normalized.addAll(recommended);
    }
    return Set<String>.unmodifiable(normalized);
  }

  static String? groupKeyForLabel(String label) {
    if (people.contains(label)) return 'person';
    if (automobiles.contains(label)) return 'vehicle';
    if (animals.contains(label)) return 'animal';
    return null;
  }

  static String? singularNameForLabel(String label) => switch (groupKeyForLabel(label)) {
        'person' => 'Pessoa',
        'vehicle' => 'Automóvel',
        'animal' => 'Animal',
        _ => null,
      };

  static String? pluralNameForLabel(String label) => switch (groupKeyForLabel(label)) {
        'person' => 'Pessoas',
        'vehicle' => 'Automóveis',
        'animal' => 'Animais',
        _ => null,
      };

  static Set<String> groupKeysForSelection(Iterable<String> labels) {
    final keys = <String>{};
    for (final label in labels) {
      final key = groupKeyForLabel(label);
      if (key != null) keys.add(key);
    }
    return Set<String>.unmodifiable(keys);
  }

  static Set<String> labelsForGroupKey(String key) => switch (key) {
        'person' => people,
        'vehicle' => automobiles,
        'animal' => animals,
        _ => const <String>{},
      };
}
