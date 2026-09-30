import '../models/detection.dart';
import '../models/object_filter_catalog.dart';

class ObjectFilterPolicy {
  const ObjectFilterPolicy._();

  static List<Detection> apply(
    Iterable<Detection> detections,
    Set<String> enabledLabels,
  ) {
    if (enabledLabels.isEmpty) return const <Detection>[];
    final allowed = ObjectFilterCatalog.normalizeSelection(enabledLabels);
    return List<Detection>.unmodifiable(
      detections.where((item) => allowed.contains(item.label)).map((item) {
        final displayLabel = ObjectFilterCatalog.singularNameForLabel(item.label);
        if (displayLabel == null) return item;
        return Detection(
          label: item.label,
          displayLabel: displayLabel,
          confidence: item.confidence,
          box: item.box,
          appearance: item.appearance,
        );
      }),
    );
  }
}
