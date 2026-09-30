import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/alert_preferences.dart';
import 'global_audio_service.dart';
import 'app_settings_service.dart';
import 'bike_sensor_service.dart';
import 'native_platform_service.dart';
import 'speech_service.dart';

enum BikeTirePosition { front, rear }

extension BikeTirePositionUi on BikeTirePosition {
  String get label => switch (this) {
        BikeTirePosition.front => 'Pneu dianteiro',
        BikeTirePosition.rear => 'Pneu traseiro',
      };

  String get spokenLabel => switch (this) {
        BikeTirePosition.front => 'pneu dianteiro',
        BikeTirePosition.rear => 'pneu traseiro',
      };
}

class BikeRapidPressureLoss {
  const BikeRapidPressureLoss({
    required this.tire,
    required this.detectedAt,
    required this.previousPsi,
    required this.currentPsi,
    required this.dropPsi,
    required this.dropPercent,
    this.prominent = true,
  });

  final BikeTirePosition tire;
  final DateTime detectedAt;
  final double previousPsi;
  final double currentPsi;
  final double dropPsi;
  final double dropPercent;
  final bool prominent;

  BikeRapidPressureLoss copyWith({
    double? currentPsi,
    double? dropPsi,
    double? dropPercent,
    bool? prominent,
  }) =>
      BikeRapidPressureLoss(
        tire: tire,
        detectedAt: detectedAt,
        previousPsi: previousPsi,
        currentPsi: currentPsi ?? this.currentPsi,
        dropPsi: dropPsi ?? this.dropPsi,
        dropPercent: dropPercent ?? this.dropPercent,
        prominent: prominent ?? this.prominent,
      );
}

class BikeRapidPressureLossDetector {
  BikeRapidPressureLossDetector({
    this.window = const Duration(seconds: 10),
    this.minimumDropPsi = 3.0,
    this.minimumDropPercent = 10.0,
    this.confirmationSamples = 2,
    this.recoverySamples = 2,
  });

  final Duration window;
  final double minimumDropPsi;
  final double minimumDropPercent;
  final int confirmationSamples;
  final int recoverySamples;

  final Map<BikeTirePosition, List<_PressureSample>> _history = {
    BikeTirePosition.front: <_PressureSample>[],
    BikeTirePosition.rear: <_PressureSample>[],
  };
  final Map<BikeTirePosition, int> _pending = {
    BikeTirePosition.front: 0,
    BikeTirePosition.rear: 0,
  };
  final Map<BikeTirePosition, int> _recovery = {
    BikeTirePosition.front: 0,
    BikeTirePosition.rear: 0,
  };
  final Map<BikeTirePosition, BikeRapidPressureLoss> _active = {};

  Map<BikeTirePosition, BikeRapidPressureLoss> get active =>
      Map<BikeTirePosition, BikeRapidPressureLoss>.unmodifiable(_active);

  BikeRapidPressureLoss? addSample(
    BikeTirePosition tire, {
    required DateTime at,
    required double psi,
    required double minimumSafePsi,
  }) {
    if (!psi.isFinite || psi <= 0) return null;
    final history = _history[tire]!;
    history.removeWhere((item) => at.difference(item.at) > window);
    final previousPeak = history.isEmpty
        ? null
        : history
            .map((item) => item.psi)
            .reduce((a, b) => math.max(a, b).toDouble());
    history.add(_PressureSample(at, psi));

    final existing = _active[tire];
    if (existing != null) {
      final drop = math.max(0, existing.previousPsi - psi).toDouble();
      final percent = existing.previousPsi <= 0
          ? 0.0
          : (drop / existing.previousPsi) * 100;
      _active[tire] = existing.copyWith(
        currentPsi: psi,
        dropPsi: drop,
        dropPercent: percent,
      );
      final recovered = psi >= minimumSafePsi &&
          psi >= existing.previousPsi - 1.0;
      _recovery[tire] = recovered ? (_recovery[tire]! + 1) : 0;
      if (_recovery[tire]! >= recoverySamples) {
        _active.remove(tire);
        _pending[tire] = 0;
        _recovery[tire] = 0;
      }
      return null;
    }

    if (previousPeak == null || previousPeak <= 0) {
      _pending[tire] = 0;
      return null;
    }
    final dropPsi = previousPeak - psi;
    final dropPercent = (dropPsi / previousPeak) * 100;
    final suspicious = dropPsi >= minimumDropPsi ||
        dropPercent >= minimumDropPercent;
    if (!suspicious) {
      _pending[tire] = 0;
      return null;
    }

    _pending[tire] = _pending[tire]! + 1;
    if (_pending[tire]! < confirmationSamples) return null;

    final event = BikeRapidPressureLoss(
      tire: tire,
      detectedAt: at,
      previousPsi: previousPeak,
      currentPsi: psi,
      dropPsi: dropPsi,
      dropPercent: dropPercent,
    );
    _active[tire] = event;
    _pending[tire] = 0;
    return event;
  }

  void clear({BikeTirePosition? tire}) {
    if (tire != null) {
      _history[tire]!.clear();
      _pending[tire] = 0;
      _recovery[tire] = 0;
      _active.remove(tire);
      return;
    }
    for (final item in BikeTirePosition.values) {
      clear(tire: item);
    }
  }

  void collapseProminent(BikeTirePosition tire) {
    final current = _active[tire];
    if (current != null && current.prominent) {
      _active[tire] = current.copyWith(prominent: false);
    }
  }
}

class BikePressureSafetyService extends ChangeNotifier {
  BikePressureSafetyService._();

  static final BikePressureSafetyService instance =
      BikePressureSafetyService._();

  static const Duration alertCooldown = Duration(seconds: 30);
  static const Duration prominentDuration = Duration(seconds: 8);

  final BikeSensorService _sensors = BikeSensorService.instance;
  final AppSettingsService _settings = AppSettingsService.instance;
  final NativePlatformService _native = NativePlatformService.instance;
  final GlobalAudioService _voice = GlobalAudioService.instance;
  final BikeRapidPressureLossDetector _detector =
      BikeRapidPressureLossDetector();
  final Map<BikeTirePosition, DateTime> _lastAlertAt = {};
  final Map<BikeTirePosition, Timer> _prominentTimers = {};

  bool _initialized = false;
  Future<void>? _initializing;
  DateTime? _lastProcessedAt;

  Map<BikeTirePosition, BikeRapidPressureLoss> get activeRapidLosses =>
      _detector.active;

  BikeRapidPressureLoss? get mostRecentRapidLoss {
    final values = _detector.active.values.toList(growable: false);
    if (values.isEmpty) return null;
    values.sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
    return values.first;
  }

  bool get hasRapidPressureLoss => _detector.active.isNotEmpty;

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _sensors.initialize();
      await _settings.initialize();
      await _voice.initialize();
      _voice.configure(_settings.profile.settings.voiceAlertPreferences);
      _voice.setEnabled(_settings.profile.settings.alertOutputs.voice);
      _sensors.addListener(_onSensorChanged);
      _initialized = true;
      _onSensorChanged();
    } finally {
      _initializing = null;
    }
  }

  void _onSensorChanged() {
    final snapshot = _sensors.snapshot;
    if (snapshot == null) return;
    if (_lastProcessedAt == snapshot.capturedAt) return;
    _lastProcessedAt = snapshot.capturedAt;

    if (!snapshot.connected) {
      notifyListeners();
      return;
    }

    final before = _detector.active.length;
    final events = <BikeRapidPressureLoss>[];
    if (snapshot.frontTirePressureAvailable) {
      final event = _detector.addSample(
        BikeTirePosition.front,
        at: snapshot.capturedAt,
        psi: snapshot.frontTirePsi,
        minimumSafePsi: snapshot.minimumTirePressurePsi,
      );
      if (event != null) events.add(event);
    }
    if (snapshot.rearTirePressureAvailable) {
      final event = _detector.addSample(
        BikeTirePosition.rear,
        at: snapshot.capturedAt,
        psi: snapshot.rearTirePsi,
        minimumSafePsi: snapshot.minimumTirePressurePsi,
      );
      if (event != null) events.add(event);
    }

    for (final event in events) {
      _scheduleCollapse(event.tire);
      unawaited(_deliverAlert(event));
    }
    if (events.isNotEmpty || before != _detector.active.length ||
        _detector.active.isNotEmpty) {
      notifyListeners();
    }
  }

  void _scheduleCollapse(BikeTirePosition tire) {
    _prominentTimers.remove(tire)?.cancel();
    _prominentTimers[tire] = Timer(prominentDuration, () {
      _detector.collapseProminent(tire);
      notifyListeners();
    });
  }

  Future<void> _deliverAlert(BikeRapidPressureLoss event) async {
    final now = DateTime.now();
    final previous = _lastAlertAt[event.tire];
    if (previous != null && now.difference(previous) < alertCooldown) return;
    _lastAlertAt[event.tire] = now;

    final profile = await _settings.initialize();
    final outputs = profile.settings.alertOutputs;
    final message =
        '${event.tire.label}: perda rápida de pressão. '
        '${event.previousPsi.toStringAsFixed(0)} para '
        '${event.currentPsi.toStringAsFixed(0)} PSI. '
        'Reduza e pare em segurança.';

    await _native.showAlertNotification(
      title: 'Vigia IA · Bike',
      message: message,
      outputs: AlertOutputs(
        voice: outputs.voice,
        sound: true,
        vibration: outputs.vibration,
        androidNotification: outputs.androidNotification,
      ),
    );

    if (outputs.voice) {
      _voice
        ..configure(profile.settings.voiceAlertPreferences)
        ..setEnabled(true);
      await _voice.deliver(
        message,
        priority: SpeechPriority.high,
        capturedAt: event.detectedAt,
      );
    }
  }

  @override
  void dispose() {
    _sensors.removeListener(_onSensorChanged);
    for (final timer in _prominentTimers.values) {
      timer.cancel();
    }
    _prominentTimers.clear();
    unawaited(_voice.disposeClient());
    super.dispose();
  }
}

class _PressureSample {
  const _PressureSample(this.at, this.psi);
  final DateTime at;
  final double psi;
}
