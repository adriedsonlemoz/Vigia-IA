import '../models/object_filter_catalog.dart';
import '../models/smart_alert_rules.dart';

class SmartAlertRuleEngine {
  SmartAlertRuleEngine(
    this._rules, {
    required this.absenceReset,
  });

  final Duration absenceReset;
  SmartAlertRules _rules;

  final Map<String, DateTime> _firstSeen = <String, DateTime>{};
  final Map<String, DateTime> _lastSeen = <String, DateTime>{};

  SmartAlertRules get rules => _rules;

  Set<String> evaluate({
    required Set<String> visibleLabels,
    required Set<String> movingLabels,
    required DateTime now,
    Duration? observationWindow,
  }) {
    final window = observationWindow != null && observationWindow > absenceReset
        ? observationWindow
        : absenceReset;
    _expireAbsent(now, window);
    final eligible = <String>{};

    for (final label in visibleLabels) {
      final previousLastSeen = _lastSeen[label];
      final isNewPresence = previousLastSeen == null ||
          now.difference(previousLastSeen) > window;
      if (isNewPresence) {
        _firstSeen[label] = now;
      }
      _lastSeen[label] = now;

      if (!_rules.enabled) {
        eligible.add(label);
        continue;
      }

      final isVehicle = ObjectFilterCatalog.vehicles.contains(label);
      if (_rules.ignoreStationaryVehicles &&
          isVehicle &&
          !movingLabels.contains(label)) {
        continue;
      }

      final firstSeen = _firstSeen[label] ?? now;
      final minimumPresence = _rules.minimumPresenceFor(label);
      if (now.difference(firstSeen) >= minimumPresence) {
        eligible.add(label);
      }
    }

    return Set<String>.unmodifiable(eligible);
  }

  void updateRules(SmartAlertRules rules) {
    _rules = rules;
    reset();
  }

  void reset() {
    _firstSeen.clear();
    _lastSeen.clear();
  }

  void _expireAbsent(DateTime now, Duration window) {
    final expired = _lastSeen.entries
        .where((entry) => now.difference(entry.value) > window)
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final label in expired) {
      _lastSeen.remove(label);
      _firstSeen.remove(label);
    }
  }
}
