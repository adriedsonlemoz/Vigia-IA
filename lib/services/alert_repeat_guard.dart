class AlertRepeatGuard {
  AlertRepeatGuard({
    required this.repeatInterval,
    required this.absenceReset,
    this.confirmationHits = 1,
    this.repeatWhilePresent = true,
  }) : assert(confirmationHits >= 1);

  final Duration repeatInterval;
  final Duration absenceReset;
  final int confirmationHits;
  final bool repeatWhilePresent;

  final Map<String, DateTime> _lastSeen = <String, DateTime>{};
  final Map<String, DateTime> _lastAlert = <String, DateTime>{};
  final Map<String, DateTime> _candidateLastSeen = <String, DateTime>{};
  final Map<String, int> _candidateHits = <String, int>{};
  final Set<String> _active = <String>{};

  List<String> evaluate(Set<String> visibleLabels, DateTime now) {
    final alerts = <String>[];

    final expired = _active.where((label) {
      final lastSeen = _lastSeen[label];
      return lastSeen == null || now.difference(lastSeen) >= absenceReset;
    }).toList(growable: false);
    for (final label in expired) {
      _active.remove(label);
      _lastSeen.remove(label);
    }

    final staleCandidates = _candidateLastSeen.entries
        .where((entry) => now.difference(entry.value) >= absenceReset)
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final label in staleCandidates) {
      _candidateLastSeen.remove(label);
      _candidateHits.remove(label);
    }

    for (final label in visibleLabels) {
      _lastSeen[label] = now;

      if (_active.contains(label)) {
        final lastAlert = _lastAlert[label];
        if (repeatWhilePresent &&
            lastAlert != null &&
            now.difference(lastAlert) >= repeatInterval) {
          alerts.add(label);
          _lastAlert[label] = now;
        }
        continue;
      }

      final previousCandidate = _candidateLastSeen[label];
      final continueCandidate = previousCandidate != null &&
          now.difference(previousCandidate) < absenceReset;
      final hits = continueCandidate ? (_candidateHits[label] ?? 0) + 1 : 1;
      _candidateLastSeen[label] = now;
      _candidateHits[label] = hits;

      if (hits < confirmationHits) continue;

      _active.add(label);
      _candidateLastSeen.remove(label);
      _candidateHits.remove(label);

      final lastAlert = _lastAlert[label];
      final minimumGapExpired = lastAlert == null ||
          now.difference(lastAlert) >= repeatInterval;
      if (minimumGapExpired || repeatWhilePresent) {
        alerts.add(label);
        _lastAlert[label] = now;
      }
    }

    return alerts;
  }

  void reset() {
    _lastSeen.clear();
    _lastAlert.clear();
    _candidateLastSeen.clear();
    _candidateHits.clear();
    _active.clear();
  }
}
