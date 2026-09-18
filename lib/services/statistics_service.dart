import '../models/monitor_event.dart';
import '../models/object_filter_catalog.dart';

class MonitoringStatistics {
  const MonitoringStatistics({
    required this.total,
    required this.today,
    required this.byObject,
    required this.byArea,
    required this.byCamera,
    required this.byHour,
    required this.busiestHour,
  });

  final int total;
  final int today;
  final Map<String, int> byObject;
  final Map<String, int> byArea;
  final Map<String, int> byCamera;
  final Map<int, int> byHour;
  final int? busiestHour;
}

class StatisticsService {
  const StatisticsService();

  MonitoringStatistics calculate(List<MonitorEvent> events, {Duration? period}) {
    final now = DateTime.now();
    final start = period == null ? null : now.subtract(period);
    final filtered = events.where((event) {
      if (start != null && event.createdAt.isBefore(start)) return false;
      return ObjectFilterCatalog.groupKeyForLabel(event.label) != null;
    }).toList(growable: false);
    final byObject = <String, int>{};
    final byArea = <String, int>{};
    final byCamera = <String, int>{};
    final byHour = <int, int>{};
    var today = 0;
    for (final event in filtered) {
      final category = ObjectFilterCatalog.singularNameForLabel(event.label);
      if (category == null) continue;
      byObject.update(category, (value) => value + 1, ifAbsent: () => 1);
      byArea.update(event.zoneName ?? 'Tela inteira', (value) => value + 1, ifAbsent: () => 1);
      byCamera.update(event.source, (value) => value + 1, ifAbsent: () => 1);
      byHour.update(event.createdAt.hour, (value) => value + 1, ifAbsent: () => 1);
      if (event.createdAt.year == now.year && event.createdAt.month == now.month && event.createdAt.day == now.day) today++;
    }
    int? busiest;
    var maxCount = -1;
    for (final entry in byHour.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        busiest = entry.key;
      }
    }
    return MonitoringStatistics(
      total: filtered.length,
      today: today,
      byObject: _sorted(byObject),
      byArea: _sorted(byArea),
      byCamera: _sorted(byCamera),
      byHour: Map<int, int>.fromEntries(byHour.entries.toList()..sort((a, b) => a.key.compareTo(b.key))),
      busiestHour: busiest,
    );
  }

  Map<String, int> _sorted(Map<String, int> source) {
    final entries = source.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map<String, int>.fromEntries(entries);
  }
}
