part of 'monitor_controller.dart';

extension _MonitorControllerEventSupport on MonitorController {
  void _updateBikeApproachFastPathImpl(
    List<Detection> primaryDetections,
    DateTime now,
  ) {
    final simulation = _bikeConfig.approachAlertsEnabled &&
        _bikeConfig.sensorSimulationEnabled &&
        _bikeConfig.simulationScenario ==
            BikeSimulationScenario.vehicleApproaching;

    BikeApproachStatus next;
    if (simulation) {
      final started = _bikeApproachSimulationStartedAt ??= now;
      final elapsedMs = now.difference(started).inMilliseconds;
      const cycleMs = 9000;
      final cycle = elapsedMs ~/ cycleMs;
      final insideCycle = (elapsedMs % cycleMs) / 1000.0;
      final ttc = (5.8 - insideCycle * 0.72).clamp(1.15, 5.8).toDouble();
      final warningTtc = _bikeConfig.approachWarningTtcSeconds;
      final criticalTtc = math.max(1.4, warningTtc * 0.55).toDouble();
      final level = ttc <= criticalTtc
          ? BikeApproachLevel.critical
          : ttc <= warningTtc
              ? BikeApproachLevel.warning
              : BikeApproachLevel.watch;
      next = BikeApproachStatus(
        level: level,
        updatedAt: now,
        trackId: -1000 - cycle,
        label: 'car',
        estimatedTtcSeconds: ttc,
        growthRatePerSecond: 1 / ttc,
        confidence: 0.98,
        simulated: true,
      );
    } else if (!_bikeConfig.enabled || !_bikeConfig.approachAlertsEnabled) {
      _bikeApproachEstimator.reset();
      next = BikeApproachStatus.clear(now);
    } else {
      next = _bikeApproachEstimator.update(
        detections: primaryDetections,
        now: now,
        baseConfidenceThreshold: _settings.confidenceThreshold,
        warningTtcSeconds: _bikeConfig.approachWarningTtcSeconds,
      );
    }

    final previous = _bikeApproachStatus;
    _bikeApproachStatus = next;
    _maybeDeliverBikeApproachAlertImpl(next, now);
    final ttcChanged = ((previous.estimatedTtcSeconds ?? 99) -
                (next.estimatedTtcSeconds ?? 99))
            .abs() >=
        0.25;
    if (previous.level != next.level ||
        previous.trackId != next.trackId ||
        previous.simulated != next.simulated ||
        (next.visible && ttcChanged)) {
      _notify();
    }
  }

  void _maybeDeliverBikeApproachAlertImpl(
    BikeApproachStatus status,
    DateTime now,
  ) {
    if (!status.shouldAlert) return;
    final trackChanged = status.trackId != _lastBikeApproachAlertTrackId;
    final escalated = _bikeApproachRankImpl(status.level) >
        _bikeApproachRankImpl(_lastBikeApproachAlertLevel);
    final cooldown = status.level == BikeApproachLevel.critical
        ? const Duration(seconds: 3)
        : const Duration(seconds: 5);
    final cooldownExpired = _lastBikeApproachAlertAt == null ||
        now.difference(_lastBikeApproachAlertAt!) >= cooldown;
    if (!trackChanged && !escalated && !cooldownExpired) return;

    _lastBikeApproachAlertAt = now;
    _lastBikeApproachAlertTrackId = status.trackId;
    _lastBikeApproachAlertLevel = status.level;
    final message = status.level == BikeApproachLevel.critical
        ? 'Aproximação rápida de veículo.'
        : 'Veículo se aproximando.';
    unawaited(
      _deliverAlertImpl(
        status.simulated ? 'Teste. $message' : message,
        priority: SpeechPriority.high,
        capturedAt: now,
      ),
    );
  }

  int _bikeApproachRankImpl(BikeApproachLevel level) => switch (level) {
        BikeApproachLevel.clear => 0,
        BikeApproachLevel.watch => 1,
        BikeApproachLevel.warning => 2,
        BikeApproachLevel.critical => 3,
      };

  void _resetBikeApproachImpl() {
    _bikeApproachEstimator.reset();
    _bikeApproachStatus =
        BikeApproachStatus.clear(DateTime.fromMillisecondsSinceEpoch(0));
    _lastBikeApproachAlertAt = null;
    _lastBikeApproachAlertTrackId = null;
    _lastBikeApproachAlertLevel = BikeApproachLevel.clear;
    _bikeApproachSimulationStartedAt = null;
  }

  bool _sameDetectionRegionImpl(Detection a, Detection b) {
    if (a.label != b.label) return false;
    final ax = (a.box.xMin + a.box.xMax) / 2;
    final ay = (a.box.yMin + a.box.yMax) / 2;
    final bx = (b.box.xMin + b.box.xMax) / 2;
    final by = (b.box.yMin + b.box.yMax) / 2;
    return (ax - bx).abs() <= 0.07 && (ay - by).abs() <= 0.07;
  }

  List<MonitoringZoneProfile> _trackingZonesImpl(
    List<MonitoringZoneProfile> activeZones,
  ) {
    if (activeZones.isNotEmpty) return activeZones;
    return const <MonitoringZoneProfile>[
      MonitoringZoneProfile(
        id: '__tela_inteira__',
        name: 'Tela inteira',
        zone: MonitoringZone.fullFrame(),
      ),
    ];
  }

  Future<void> _recordConfirmedEventsImpl(
    RgbFrame frame,
    List<String> alertKeys,
    Map<String, Detection> alertTargets,
  ) async {
    final session = _frameSession;
    final source = _sourceDisplayNameImpl;
    final eventIds = <String>[];
    final now = DateTime.now();
    for (final key in alertKeys) {
      if (_shouldDiscardFrameResult(session)) return;
      final detection = alertTargets[key];
      if (detection == null) continue;
      final tracked = _trackedDetections
          .where((item) => identical(item.detection, detection))
          .firstOrNull;
      final zones = MonitoringZoneService.zonesForDetection(
        detection,
        _trackingZonesImpl(activeMonitoringZones),
      );
      final zone = zones.firstOrNull;
      final message = _settings.alertMessages.resolve(
        label: detection.label,
        displayLabel: detection.displayLabel,
        zoneName: zone?.name,
      );
      if (_shouldDeliverRepeatedAlertImpl(
        detection,
        trackId: tracked?.trackId,
        now: now,
      )) {
        unawaited(
          _deliverAlertImpl(
            message,
            audioSlot: _audioSlotForLabelImpl(detection.label),
            capturedAt: frame.capturedAt,
          ),
        );
      }
      final event = await _eventHistory.addEvent(
        detection: detection,
        frame: frame,
        source: source,
        type: MonitorEventType.alert,
        trackId: tracked?.trackId,
        zoneId: zone?.id,
        zoneName: zone?.name,
        cameraId: sourceConfig.cameraId,
      );
      if (event != null) eventIds.add(event.id);
    }

    if (_shouldDiscardFrameResult(session)) return;
    if (_clipRecordingEnabled && eventIds.isNotEmpty) {
      final clipPath = await _clipRecorder.trigger();
      if (clipPath != null && clipPath.isNotEmpty) {
        await _eventHistory.attachClip(eventIds, clipPath);
      }
    }
    if (_settings.storagePolicy.autoCleanup && eventIds.isNotEmpty) {
      unawaited(_eventHistory.applyStoragePolicy(_settings.storagePolicy));
    }
  }

  Future<void> _recordTransitionsImpl(
    RgbFrame frame,
    List<ZoneTransition> transitions,
  ) async {
    final session = _frameSession;
    final initialTrackIds = transitions
        .where((transition) =>
            transition.type == ZoneTransitionType.entered &&
            !_seenTrackIds.contains(transition.trackId))
        .map((transition) => transition.trackId)
        .toSet();
    _seenTrackIds.addAll(initialTrackIds);

    for (final transition in transitions) {
      if (_shouldDiscardFrameResult(session)) return;
      final detection = transition.detection;
      if (detection == null) continue;
      if (transition.type == ZoneTransitionType.entered &&
          initialTrackIds.contains(transition.trackId)) {
        continue;
      }
      _seenTrackIds.add(transition.trackId);
      if (_announceEntryExit && _allowTransitionSpeechImpl(transition)) {
        final eventName = transition.type == ZoneTransitionType.entered
            ? 'entered'
            : 'exited';
        final message = _settings.alertMessages.resolve(
          label: transition.label,
          displayLabel: transition.displayLabel,
          zoneName: transition.zoneName,
          event: eventName,
        );
        unawaited(
          _deliverAlertImpl(
            message,
            priority: SpeechPriority.high,
            audioSlot: _audioSlotForTransitionImpl(transition),
            capturedAt: frame.capturedAt,
          ),
        );
      }
      await _eventHistory.addEvent(
        detection: detection,
        frame: frame,
        source: _sourceDisplayNameImpl,
        type: transition.type == ZoneTransitionType.entered
            ? MonitorEventType.entered
            : MonitorEventType.exited,
        trackId: transition.trackId,
        zoneId: transition.zoneId,
        zoneName: transition.zoneName,
        cameraId: sourceConfig.cameraId,
      );
    }
  }

  bool _shouldDeliverRepeatedAlertImpl(
    Detection detection, {
    required DateTime now,
    int? trackId,
  }) {
    final retention = Duration(
      milliseconds: (_settings.absenceReset.inMilliseconds * 6)
          .clamp(9000, 18000)
          .toInt(),
    );
    _recentAlertMemory.removeWhere(
      (_, memory) => now.difference(memory.timestamp) > retention,
    );

    final group = ObjectFilterCatalog.groupKeyForLabel(detection.label) ?? detection.label;
    for (final entry in _recentAlertMemory.entries) {
      final memory = entry.value;
      if (memory.group != group) continue;
      if (trackId != null && memory.trackId != null && memory.trackId == trackId) {
        _recentAlertMemory[entry.key] = memory.copyWith(timestamp: now, box: detection.box, appearance: detection.appearance);
        return false;
      }

      final overlap = _iouImpl(memory.box, detection.box);
      final distance = _centerDistanceImpl(memory.box, detection.box);
      final appearanceSimilarity = ObjectAppearanceService.similarity(
        memory.appearance,
        detection.appearance,
      );
      final similar = overlap >= 0.34 ||
          (distance <= 0.16 && appearanceSimilarity >= 0.64) ||
          (distance <= 0.10 && overlap >= 0.20);
      if (!similar) continue;
      _recentAlertMemory[entry.key] = memory.copyWith(
        timestamp: now,
        box: detection.box,
        appearance: detection.appearance,
        trackId: trackId ?? memory.trackId,
      );
      return false;
    }

    final key = '${group}_${now.microsecondsSinceEpoch}';
    _recentAlertMemory[key] = _RecentAlertMemory(
      group: group,
      timestamp: now,
      box: detection.box,
      appearance: detection.appearance,
      trackId: trackId,
    );
    return true;
  }

  double _centerDistanceImpl(NormalizedBox a, NormalizedBox b) {
    final ax = (a.xMin + a.xMax) / 2;
    final ay = (a.yMin + a.yMax) / 2;
    final bx = (b.xMin + b.xMax) / 2;
    final by = (b.yMin + b.yMax) / 2;
    final dx = ax - bx;
    final dy = ay - by;
    return math.sqrt(dx * dx + dy * dy);
  }

  double _iouImpl(NormalizedBox a, NormalizedBox b) {
    final left = a.xMin > b.xMin ? a.xMin : b.xMin;
    final top = a.yMin > b.yMin ? a.yMin : b.yMin;
    final right = a.xMax < b.xMax ? a.xMax : b.xMax;
    final bottom = a.yMax < b.yMax ? a.yMax : b.yMax;
    final intersectionWidth = (right - left).clamp(0.0, 1.0).toDouble();
    final intersectionHeight = (bottom - top).clamp(0.0, 1.0).toDouble();
    final intersection = intersectionWidth * intersectionHeight;
    final areaA = (a.xMax - a.xMin).clamp(0.0, 1.0) * (a.yMax - a.yMin).clamp(0.0, 1.0);
    final areaB = (b.xMax - b.xMin).clamp(0.0, 1.0) * (b.yMax - b.yMin).clamp(0.0, 1.0);
    final union = areaA + areaB - intersection;
    return union <= 0 ? 0.0 : intersection / union;
  }

  String _audioSlotForLabelImpl(String label) =>
      switch (ObjectFilterCatalog.groupKeyForLabel(label)) {
        'person' => AudioSlotIds.personDetected,
        'vehicle' => AudioSlotIds.vehicleDetected,
        'animal' => AudioSlotIds.animalDetected,
        _ => AudioSlotIds.objectDetected,
      };

  String _audioSlotForTransitionImpl(ZoneTransition transition) {
    final entered = transition.type == ZoneTransitionType.entered;
    return switch (ObjectFilterCatalog.groupKeyForLabel(transition.label)) {
      'person' => entered ? AudioSlotIds.personEntered : AudioSlotIds.personExited,
      'vehicle' => entered ? AudioSlotIds.vehicleEntered : AudioSlotIds.vehicleExited,
      'animal' => entered ? AudioSlotIds.animalEntered : AudioSlotIds.animalExited,
      _ => entered ? AudioSlotIds.objectEntered : AudioSlotIds.objectExited,
    };
  }

  bool _allowTransitionSpeechImpl(ZoneTransition transition) {
    final now = transition.occurredAt;
    final key = '${transition.trackId}|${transition.zoneId}';
    final previous = _lastTransitionSpeechAt[key];
    _lastTransitionSpeechAt.removeWhere(
      (_, timestamp) => now.difference(timestamp) > const Duration(minutes: 2),
    );
    if (previous != null &&
        now.difference(previous) < const Duration(seconds: 5)) {
      return false;
    }
    _lastTransitionSpeechAt[key] = now;
    return true;
  }

  String get _sourceDisplayNameImpl => sourceConfig.displayName ?? switch (sourceConfig.type) {
        VideoSourceType.localCamera => 'Câmera do dispositivo',
        VideoSourceType.rtsp => 'Câmera RTSP',
        VideoSourceType.remotePhone => 'Celular remoto',
      };

  Future<void> _deliverAlertImpl(
    String message, {
    SpeechPriority priority = SpeechPriority.normal,
    String? audioSlot,
    DateTime? capturedAt,
  }) async {
    if (_disposed || _suspended || !_scheduleActive) return;
    if (capturedAt != null && !DetectionCadencePolicy.fresh(capturedAt,
        DateTime.now(), DetectionCadencePolicy.spokenFrameMaxAge)) return;
    final futures = <Future<void>>[];
    if (_settings.alertOutputs.voice && _speech.enabled) {
      futures.add(_speech.deliver(message, audioSlot: audioSlot,
          priority: priority, capturedAt: capturedAt));
    }
    if (_settings.alertOutputs.androidNotification ||
        _settings.alertOutputs.sound ||
        _settings.alertOutputs.vibration) {
      futures.add(
        _native.showAlertNotification(
          title: 'Vigia IA',
          message: message,
          outputs: _settings.alertOutputs,
        ),
      );
    }
    if (futures.isNotEmpty) await Future.wait(futures);
  }

  Future<void> _handleCameraIntegrityIssueImpl(
    RgbFrame frame,
    CameraIntegrityIssue issue,
  ) async {
    final isObstructed = issue == CameraIntegrityIssue.obstructed;
    _health.markCameraWarning(
      isObstructed ? CameraHealthState.obstructed : CameraHealthState.moved,
    );
    final message = _settings.alertMessages.resolve(
      label: 'camera',
      displayLabel: 'Câmera',
      event: isObstructed ? 'cameraObstructed' : 'cameraMoved',
    );
    unawaited(
      _deliverAlertImpl(
        message,
        priority: SpeechPriority.high,
        audioSlot: isObstructed ? AudioSlotIds.cameraObstructed : AudioSlotIds.cameraMoved,
      ),
    );
    await _logs.record(
      level: ErrorLogLevel.warning,
      source: 'Integridade da câmera',
      message: message,
      context: <String, Object?>{'fonte': _sourceDisplayNameImpl},
    );
    // Integridade da câmera é informação técnica: fica no Diagnóstico e
    // não entra no Histórico de passagem de pessoas/automóveis/animais.
  }

}
