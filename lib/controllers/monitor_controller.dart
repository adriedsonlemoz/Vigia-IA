import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/video_source.dart';
import '../core/video_source_status.dart';
import '../models/audio_slot.dart';
import '../models/bike_approach_status.dart';
import '../models/bike_mode_config.dart';
import '../models/detection.dart';
import '../models/device_telemetry.dart';
import '../models/monitor_event.dart';
import '../models/monitor_schedule.dart';
import '../models/monitoring_zone.dart';
import '../models/object_appearance.dart';
import '../models/object_filter_catalog.dart';
import '../models/remote_phone_status.dart';
import '../models/rgb_frame.dart';
import '../models/session_status.dart';
import '../models/smart_alert_rules.dart';
import '../models/system_health.dart';
import '../models/tracked_detection.dart';
import '../models/video_source_config.dart';
import '../services/alert_repeat_guard.dart';
import '../services/analysis_budget_policy.dart';
import '../services/app_settings_service.dart';
import '../services/background_monitor_service.dart';
import '../services/bike_approach_estimator.dart';
import '../services/bike_mode_service.dart';
import '../services/camera_integrity_service.dart';
import '../services/clip_recorder_service.dart';
import '../services/detection_confidence_policy.dart';
import '../services/detection_merger.dart';
import '../services/detection_scan_planner.dart';
import '../services/error_log_service.dart';
import '../services/event_history_service.dart';
import '../services/motion_detection_service.dart';
import '../services/native_platform_service.dart';
import '../services/monitoring_zone_service.dart';
import '../services/monitor_lan_stream_service.dart';
import '../services/object_appearance_service.dart';
import '../services/object_detection_service.dart';
import '../services/object_filter_policy.dart';
import '../services/object_tracker.dart';
import '../services/partial_person_detection_service.dart';
import '../services/smart_alert_rule_engine.dart';
import '../services/temporal_detection_filter.dart';
import '../services/shared_local_camera_service.dart';
import '../services/runtime_health_service.dart';
import '../services/speech_service.dart';
import '../sources/local_camera_source.dart';
import '../sources/rtsp_camera_source.dart';
import '../sources/remote_phone_camera_source.dart';

part 'monitor_controller_session_support.dart';
part 'monitor_controller_event_support.dart';
part 'monitor_controller_state_support.dart';

class MonitorController extends ChangeNotifier {
  MonitorController({
    required this.sourceConfig,
    required MonitorSettings settings,
  })  : _settings = settings,
        _alertLabels = <String>{...settings.alertLabels},
        _monitoringZones = settings.monitoringZones
            .map((item) => item.copyWith(zone: item.zone.normalized()))
            .toList(growable: true),
        _smartAlertRules = settings.smartAlertRules,
        _backgroundMonitoringEnabled = settings.backgroundMonitoringEnabled,
        _schedule = settings.schedule,
        _clipRecordingEnabled = settings.clipRecordingEnabled,
        _trackingEnabled = settings.trackingEnabled,
        _announceEntryExit = settings.announceEntryExit,
        _tracker = ObjectTracker(
          maxMissing: settings.absenceReset.inMilliseconds < 1600
              ? const Duration(milliseconds: 1600)
              : settings.absenceReset,
          identityRetention: const Duration(seconds: 12),
        ) {
    _lanStream.addListener(_onLanStreamChanged);
    _bikeMode.addListener(_onBikeModeChanged);
  }

  MonitorSettings _settings;
  VideoSourceConfig sourceConfig;

  ObjectDetectionService _detector = ObjectDetectionService();
  final SpeechService _speech = SpeechService();
  final MotionDetectionService _motion = MotionDetectionService();
  final TemporalDetectionFilter _detectionFilter = TemporalDetectionFilter();
  final CameraIntegrityService _cameraIntegrity = CameraIntegrityService();
  final NativePlatformService _native = NativePlatformService.instance;
  final RuntimeHealthService _health = RuntimeHealthService.instance;
  final ErrorLogService _logs = ErrorLogService.instance;
  final EventHistoryService _eventHistory = EventHistoryService.instance;
  final AppSettingsService _appSettings = AppSettingsService.instance;
  final BikeModeService _bikeMode = BikeModeService.instance;
  final BikeApproachEstimator _bikeApproachEstimator = BikeApproachEstimator();
  final ClipRecorderService _clipRecorder = ClipRecorderService();
  final MonitorLanStreamService _lanStream = MonitorLanStreamService();
  late AlertRepeatGuard _alertGuard;
  late SmartAlertRuleEngine _smartRuleEngine;
  final ObjectTracker _tracker;
  Set<String> _alertLabels;
  SmartAlertRules _smartAlertRules;
  List<MonitoringZoneProfile> _monitoringZones;
  List<TrackedDetection> _trackedDetections = const <TrackedDetection>[];
  final Set<int> _seenTrackIds = <int>{};
  bool _backgroundMonitoringEnabled;
  MonitorSchedule _schedule;
  bool _clipRecordingEnabled;
  bool _trackingEnabled;
  bool _announceEntryExit;
  bool _scheduleActive = true;
  double? _previewAspectRatio;

  VideoSource? _source;
  StreamSubscription<RgbFrame>? _frameSubscription;
  StreamSubscription<VideoSourceStatus>? _statusSubscription;
  Timer? _scheduleTimer;
  Timer? _backgroundHealthTimer;
  Timer? _bikeTelemetryTimer;
  Timer? _sessionTelemetryTimer;
  List<Detection> _detections = const [];
  VideoSourceStatus _sourceStatus =
      const VideoSourceStatus(VideoSourceState.idle);
  String? _error;
  bool _processing = false;
  bool _initializing = true;
  bool _baseReady = false;
  bool _suspended = false;
  bool _disposed = false;
  bool _motionActive = false;
  bool _cameraMotion = false;
  double _motionScore = 0;
  int _frameSession = 0;
  Completer<void>? _processingDone;
  Future<void> _transitionTail = Future<void>.value();
  DateTime? _lastFrameReceivedAt;
  DateTime? _lastNotificationUpdateAt;
  DateTime? _lastRecoveryAttemptAt;
  bool _appInBackground = false;
  bool _backgroundRecoveryInProgress = false;
  double _fps = 0;
  double _receivedFps = 0;
  DateTime? _lastReceivedFpsSample;
  DateTime? _lastAnalyzedFpsSample;
  int _framesReceived = 0;
  int _framesAnalyzed = 0;
  int _framesDropped = 0;
  int _framesDroppedProcessing = 0;
  int _framesSkippedOptimization = 0;
  int? _lastFrameWidth;
  int? _lastFrameHeight;
  int? _lastAnalysisWidth;
  int? _lastAnalysisHeight;
  int? _lastFrameDelayMs;
  double? _lastInferenceMs;
  double? _lastPreprocessMs;
  double? _lastPrimaryInferenceMs;
  double? _lastAuxiliaryInferenceMs;
  double? _lastPostprocessMs;
  double? _lastTotalProcessingMs;
  double? _lastEndToEndMs;
  int _lastDetectorRuns = 0;
  int _lastAuxiliaryInferenceRuns = 0;
  int _detailScansSkippedByBudget = 0;
  DeviceTelemetrySnapshot? _localDeviceTelemetry;
  final List<SessionHealthIncident> _sessionHealthIncidents = <SessionHealthIncident>[];
  String? _lastSessionHealthFingerprint;
  DateTime? _lastIdleInferenceAt;
  DateTime? _lastDetailScanAt;
  int _detailTileIndex = 0;
  final Map<int, DateTime> _recentMotionByTrackId = <int, DateTime>{};
  final Map<String, DateTime> _lastTransitionSpeechAt = <String, DateTime>{};
  final Map<String, _RecentAlertMemory> _recentAlertMemory = <String, _RecentAlertMemory>{};
  String? _lanPermissionError;
  BikeModeConfig _bikeConfig = const BikeModeConfig();
  BikeApproachStatus _bikeApproachStatus =
      BikeApproachStatus.clear(DateTime.fromMillisecondsSinceEpoch(0));
  DateTime? _lastBikeApproachAlertAt;
  int? _lastBikeApproachAlertTrackId;
  BikeApproachLevel _lastBikeApproachAlertLevel = BikeApproachLevel.clear;
  DateTime? _bikeApproachSimulationStartedAt;
  bool _bikeLowBatteryAlerted = false;
  bool _bikePolicyChangeInProgress = false;

  List<Detection> get detections => _detections;
  List<TrackedDetection> get trackedDetections => _trackedDetections;
  VideoSourceStatus get sourceStatus => _sourceStatus;
  String? get error => _error;
  bool get initializing => _initializing;
  bool get processing => _processing;
  bool get voiceEnabled => _speech.enabled;
  bool get voiceLanguageInstalled => _speech.languageInstalled;
  bool get motionOnly => _settings.motionOnly;
  bool get motionActive => _motionActive;
  bool get cameraMotion => _cameraMotion;
  double get motionScore => _motionScore;
  Set<String> get alertLabels => Set<String>.unmodifiable(_alertLabels);
  SmartAlertRules get smartAlertRules => _smartAlertRules;
  List<MonitoringZoneProfile> get monitoringZones =>
      List<MonitoringZoneProfile>.unmodifiable(_monitoringZones);
  List<MonitoringZoneProfile> get activeMonitoringZones => _monitoringZones
      .where((zone) => zone.enabled)
      .toList(growable: false);
  bool get monitoringZonesEnabled => activeMonitoringZones.isNotEmpty;
  double? get previewAspectRatio => _previewAspectRatio;
  bool get backgroundMonitoringEnabled => _backgroundMonitoringEnabled;
  bool get lanStreamRunning => _lanStream.running;
  bool get lanStreamStarting => _lanStream.starting;
  String? get lanViewerUrl => _lanStream.viewerUrl;
  String? get lanBaseAddress => _lanStream.baseAddress;
  String get lanAccessKey => _lanStream.accessKey;
  int get lanConnectedViewers => _lanStream.connectedViewers;
  String? get lanStreamError => _lanPermissionError ?? _lanStream.error;
  DateTime? get lanLastFrameAt => _lanStream.lastFrameAt;
  MonitorSchedule get schedule => _schedule;
  bool get scheduleActive => _scheduleActive;
  bool get clipRecordingEnabled => _clipRecordingEnabled;
  bool get clipRecording => _clipRecorder.recording;
  bool get trackingEnabled => _trackingEnabled;
  bool get announceEntryExit => _announceEntryExit;
  Duration get clipDuration => _settings.clipDuration;
  ClipFormatPreference get clipFormatPreference => _settings.clipFormatPreference;
  bool get cameraIntegrityEnabled => _settings.cameraIntegrityEnabled;
  MonitorSettings get currentSettings => _runtimeSettings();
  BikeModeConfig get bikeModeConfig => _bikeConfig;
  BikeApproachStatus get bikeApproachStatus => _bikeApproachStatus;
  bool get isRemotePhoneSource => sourceConfig.type == VideoSourceType.remotePhone;
  RemotePhoneStatus? get remotePhoneStatus {
    final source = _source;
    return source is RemotePhoneCameraSource ? source.remoteStatus : null;
  }
  int get remotePhoneWarningCount => remotePhoneStatus?.warnings().length ?? 0;
  DeviceTelemetrySnapshot? get localDeviceTelemetry => _localDeviceTelemetry;

  SessionStatusData get sessionStatus => _buildSessionStatus();

  SessionStatusData _buildSessionStatus() => this._buildSessionStatusImpl();

  void _sampleSessionHealth() => this._sampleSessionHealthImpl();

  Duration get effectiveAnalysisInterval =>
      _bikeConfig.effectiveAnalysisInterval(sourceConfig.analysisInterval);

  Widget buildPreview() =>
      _source?.buildPreview() ?? const SizedBox.expand();

  void _syncLanHealth() {
    _health.updateLan(
      active: _lanStream.running,
      clients: _lanStream.connectedViewers,
      lastFrameAt: _lanStream.lastFrameAt,
      error: _lanPermissionError ?? _lanStream.error,
    );
  }

  void _notify() {
    _syncLanHealth();
    if (!_disposed) notifyListeners();
  }

  void _onLanStreamChanged() => _notify();

  void _onRemotePhoneStatusChanged() => _notify();

  void _onBikeModeChanged() {
    if (_disposed || _bikePolicyChangeInProgress) return;
    unawaited(_applyBikeModeChange());
  }

  Future<void> _applyBikeModeChange() async {
    if (_disposed || _bikePolicyChangeInProgress) return;
    _bikePolicyChangeInProgress = true;
    try {
      final previous = _bikeConfig;
      final next = _bikeMode.config;
      final previousInterval = previous.effectiveAnalysisInterval(sourceConfig.analysisInterval);
      final nextInterval = next.effectiveAnalysisInterval(sourceConfig.analysisInterval);
      _bikeConfig = next;
      if (!next.enabled &&
          !(next.approachAlertsEnabled &&
              next.sensorSimulationEnabled &&
              next.simulationScenario == BikeSimulationScenario.vehicleApproaching)) {
        _resetBikeApproach();
      } else if (previous.simulationScenario != next.simulationScenario ||
          previous.sensorSimulationEnabled != next.sensorSimulationEnabled ||
          previous.approachAlertsEnabled != next.approachAlertsEnabled ||
          previous.approachWarningTtcSeconds != next.approachWarningTtcSeconds) {
        _resetBikeApproach();
      }
      _lanStream
        ..setMaxFps(next.streamFpsCap)
        ..setBikeModeState(enabled: next.enabled, profile: next.powerProfile.name)
        ..setEncodingPolicy(
          maxWidth: next.enabled ? next.powerProfile.targetJpegWidth : 960,
          quality: next.enabled ? next.powerProfile.targetJpegQuality : 76,
        );
      await _applyBikeScreenPolicy();
      _configureBikeTelemetryTimer();
      if (previousInterval != nextInterval &&
          _source != null &&
          _scheduleActive &&
          !_suspended) {
        await _enqueueTransition(() async {
          if (_disposed || _source == null || !_scheduleActive || _suspended) return;
          await _stopSourceUnlocked();
          await _startSourceUnlocked(sourceConfig);
        });
      }
      _notify();
    } finally {
      _bikePolicyChangeInProgress = false;
    }
  }

  Future<void> _applyBikeScreenPolicy() => _native.setBikeScreenBrightness(
        _source != null ? _bikeConfig.rearScreenBrightness : null,
      );

  void _startSessionTelemetryTimer() => this._startSessionTelemetryTimerImpl();

  Future<void> _refreshSessionTelemetry() => this._refreshSessionTelemetryImpl();

  void _configureBikeTelemetryTimer() => this._configureBikeTelemetryTimerImpl();

  Future<void> _refreshBikeTelemetry() => this._refreshBikeTelemetryImpl();

  Future<bool> ensureLanStreaming({bool requestPermission = false}) async {
    if (_disposed || _source == null || !_scheduleActive) return false;
    _lanPermissionError = null;

    final permission = await _native.localNetworkPermissionStatus();
    if (permission.required && !permission.granted) {
      final granted = await _native.requestLocalNetworkPermission();
      if (!granted) {
        _lanPermissionError =
            'Acesso à rede local não autorizado. Permita o acesso a dispositivos próximos/rede local para transmitir para outro celular.';
        _notify();
        return false;
      }
    } else if (requestPermission && !permission.granted) {
      final granted = await _native.requestLocalNetworkPermission();
      if (!granted) {
        _lanPermissionError =
            'A permissão necessária para acessar a rede local não foi concedida.';
        _notify();
        return false;
      }
    }

    var started = await _lanStream.start();
    if (!started && _lanStream.likelyPermissionError) {
      final granted = await _native.requestLocalNetworkPermission();
      if (granted) started = await _lanStream.start();
    }
    if (!started) {
      unawaited(
        _logs.record(
          level: ErrorLogLevel.warning,
          source: 'Rede local',
          message: lanStreamError ??
              'A transmissão pela rede local não pôde ser iniciada.',
          context: _diagnosticContext(),
        ),
      );
    }
    _notify();
    return started;
  }

  Future<void> initialize() async {
    if (_disposed || _baseReady) return;
    _initializing = true;
    _error = null;
    _scheduleActive = _schedule.isActiveAt(DateTime.now());
    _notify();
    _alertGuard = AlertRepeatGuard(
      repeatInterval: _settings.repeatInterval,
      absenceReset: _settings.absenceReset,
      confirmationHits: _settings.motionConfirmationHits,
      repeatWhilePresent: false,
    );
    _smartRuleEngine = SmartAlertRuleEngine(
      _smartAlertRules,
      absenceReset: _settings.absenceReset,
    );

    try {
      _bikeConfig = await _bikeMode.initialize();
      _lanStream
        ..setMaxFps(_bikeConfig.streamFpsCap)
        ..setBikeModeState(enabled: _bikeConfig.enabled, profile: _bikeConfig.powerProfile.name)
        ..setEncodingPolicy(
          maxWidth: _bikeConfig.enabled ? _bikeConfig.powerProfile.targetJpegWidth : 960,
          quality: _bikeConfig.enabled ? _bikeConfig.powerProfile.targetJpegQuality : 76,
        );
      _configureBikeTelemetryTimer();
      _startSessionTelemetryTimer();
      _clipRecorder.configure(
        clipDuration: _settings.clipDuration,
        format: _settings.clipFormatPreference,
      );
      await Future.wait(<Future<void>>[
        _detector.initialize(),
        _speech.initialize(),
        _clipRecorder.initialize(),
      ]);
      _speech.setEnabled(_settings.alertOutputs.voice);
      if (_disposed) return;
      _baseReady = true;
      _health.aiReady = _detector.isReady;
      _startScheduleTimer();
      _startBackgroundHealthTimer();
      if (_backgroundMonitoringEnabled) {
        final started = await _ensureBackgroundService(
          statusText: _scheduleActive
              ? 'Preparando monitoramento…'
              : 'Serviço ativo • aguardando o horário programado.',
        );
        if (!started) {
          _backgroundMonitoringEnabled = false;
          _settings = _settings.copyWith(backgroundMonitoringEnabled: false);
          unawaited(_persistRuntime());
          unawaited(
            _logs.record(
              level: ErrorLogLevel.warning,
              source: 'Segundo plano',
              message: 'O Android recusou iniciar o serviço em primeiro plano; a opção foi desativada para não indicar um estado falso.',
            ),
          );
        }
      }
      unawaited(
        _logs.record(
          level: ErrorLogLevel.info,
          source: 'Detector',
          message: 'Modelo de detecção inicializado.',
          context: <String, Object?>{
            'diagnóstico': _detector.diagnostics ?? 'não informado',
          },
        ),
      );
      if (!_suspended && _scheduleActive) {
        await _enqueueTransition(() async {
          if (_disposed ||
              _suspended ||
              !_baseReady ||
              !_scheduleActive ||
              _source != null) {
            return;
          }
          await _startSourceUnlocked(sourceConfig);
        });
      } else if (!_scheduleActive) {
        _sourceStatus = const VideoSourceStatus(
          VideoSourceState.stopped,
          message: 'Fora do horário agendado',
        );
      }
    } catch (error, stackTrace) {
      _baseReady = false;
      _error =
          'Falha ao iniciar a IA. Consulte a Central de Erros ou tente novamente.';
      unawaited(
        _logs.recordException(
          source: 'Inicialização',
          error: error,
          stackTrace: stackTrace,
          message: 'Falha ao inicializar detector, voz ou fonte de vídeo.',
          context: _diagnosticContext(),
        ),
      );
    } finally {
      _initializing = false;
      _notify();
    }
  }

  Future<void> retry() async {
    if (_disposed || _initializing) return;
    _initializing = true;
    _baseReady = false;
    _error = null;
    _resetEventState();
    _notify();

    await _enqueueTransition(_stopSourceUnlocked);
    await _waitForProcessing();
    final oldDetector = _detector;
    _detector = ObjectDetectionService();
    try {
      await oldDetector.dispose();
    } catch (_) {}

    try {
      await Future.wait(<Future<void>>[
        _detector.initialize(),
        _speech.initialize(),
      ]);
      if (_disposed) return;
      _baseReady = true;
      _health.aiReady = _detector.isReady;
      await _logs.record(
        level: ErrorLogLevel.info,
        source: 'Recuperação',
        message: 'Detector reinicializado com sucesso.',
        context: <String, Object?>{
          'diagnóstico': _detector.diagnostics ?? 'não informado',
        },
      );
      await _applyScheduleState();
    } catch (error, stackTrace) {
      _baseReady = false;
      _error =
          'Não foi possível recuperar o monitoramento. Consulte a Central de Erros.';
      unawaited(
        _logs.recordException(
          source: 'Recuperação',
          error: error,
          stackTrace: stackTrace,
          message: 'Falha ao tentar reinicializar o monitoramento.',
          context: _diagnosticContext(),
        ),
      );
    } finally {
      _initializing = false;
      _notify();
    }
  }

  void _startScheduleTimer() {
    _scheduleTimer?.cancel();
    _backgroundHealthTimer?.cancel();
    _scheduleTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_applyScheduleState()),
    );
  }

  Future<void> _applyScheduleState() async {
    if (_disposed || !_baseReady) return;
    final shouldBeActive = _schedule.isActiveAt(DateTime.now());
    if (_scheduleActive == shouldBeActive &&
        ((shouldBeActive && _source != null) ||
            (!shouldBeActive && _source == null))) {
      return;
    }
    _scheduleActive = shouldBeActive;
    if (!shouldBeActive) {
      await _enqueueTransition(_stopSourceUnlocked);
      _sourceStatus = const VideoSourceStatus(
        VideoSourceState.stopped,
        message: 'Fora do horário agendado',
      );
      _notify();
      return;
    }
    if (_suspended && !_backgroundMonitoringEnabled) return;
    try {
      await _enqueueTransition(() async {
        if (_disposed || !_baseReady || !_scheduleActive || _source != null) {
          return;
        }
        await _startSourceUnlocked(sourceConfig);
      });
    } catch (error, stackTrace) {
      final scheduled = _schedule.enabled;
      unawaited(
        _logs.recordException(
          source: scheduled ? 'Agendamento' : 'Inicialização da fonte',
          error: error,
          stackTrace: stackTrace,
          message: scheduled
              ? 'Falha ao iniciar monitoramento pelo horário programado.'
              : 'Falha ao iniciar a fonte de vídeo.',
          context: _diagnosticContext(),
        ),
      );
    }
    _notify();
  }

  Future<void> _startSourceUnlocked(VideoSourceConfig config) async {
    if (_disposed || (_suspended && !_backgroundMonitoringEnabled) || !_baseReady) {
      return;
    }
    if (!_scheduleActive) return;

    _resetSessionMetrics();
    final analysisInterval = _bikeConfig.effectiveAnalysisInterval(
      config.analysisInterval,
    );
    final source = switch (config.type) {
      VideoSourceType.localCamera => LocalCameraSource(
          analysisInterval: analysisInterval,
        ),
      VideoSourceType.rtsp => RtspCameraSource(
          url: config.rtspUrl ?? '',
          analysisInterval: analysisInterval,
        ),
      VideoSourceType.remotePhone => RemotePhoneCameraSource(
          baseUrl: config.remoteBaseUrl ?? '',
          accessKey: config.remoteAccessKey ?? '',
          analysisInterval: analysisInterval,
        ),
    };
    _source = source;
    sourceConfig = config;
    if (source is RemotePhoneCameraSource) {
      source.remoteStatusNotifier.addListener(_onRemotePhoneStatusChanged);
    }
    _sourceStatus = const VideoSourceStatus(VideoSourceState.connecting);
    _health.updateSource(
      name: _sourceDisplayName,
      monitoring: true,
      active: false,
    );
    _frameSubscription = source.frames.listen(_onFrame);
    _statusSubscription = source.statuses.listen((status) {
      final previousState = _sourceStatus.state;
      _sourceStatus = status;
      _health.updateSource(
        name: _sourceDisplayName,
        monitoring: _source != null && _scheduleActive,
        active: status.state == VideoSourceState.streaming,
      );
      _sampleSessionHealth();
      if (status.state == VideoSourceState.error &&
          previousState == VideoSourceState.streaming) {
        unawaited(
          _logs.record(
            level: ErrorLogLevel.error,
            source: 'Fonte de vídeo',
            message: status.message ?? 'Erro na fonte de vídeo.',
            context: _diagnosticContext(),
          ),
        );
      }
      _notify();
    });
    _notify();

    try {
      if (_backgroundMonitoringEnabled) {
        final started = await _ensureBackgroundService(
          statusText: config.type == VideoSourceType.localCamera
              ? 'Preparando câmera para monitoramento em segundo plano…'
              : 'Preparando monitoramento em segundo plano…',
        );
        if (!started) {
          _backgroundMonitoringEnabled = false;
          _settings = _settings.copyWith(backgroundMonitoringEnabled: false);
          _health.backgroundActive = false;
          unawaited(_persistRuntime());
          unawaited(
            _logs.record(
              level: ErrorLogLevel.warning,
              source: 'Segundo plano',
              message: 'O serviço Android de segundo plano não pôde ser iniciado; o monitor seguirá apenas em primeiro plano.',
            ),
          );
        }
      }
      await source.start();
      await _applyBikeScreenPolicy();
      await ensureLanStreaming();
      if (_bikeConfig.enabled && _bikeConfig.keepRemoteTelemetry) {
        unawaited(_refreshBikeTelemetry());
      }
      if (_backgroundMonitoringEnabled) {
        await BackgroundMonitorService.updateStatus(
          config.type == VideoSourceType.localCamera
              ? 'Monitoramento ativo • câmera e IA recebendo imagens.'
              : 'Monitoramento ativo • fonte de vídeo e IA em execução.',
        );
      }
    } catch (error, stackTrace) {
      await _frameSubscription?.cancel();
      await _statusSubscription?.cancel();
      _frameSubscription = null;
      _statusSubscription = null;
      _source = null;
      _sourceStatus = const VideoSourceStatus(VideoSourceState.error);
      try {
        await source.dispose();
      } catch (_) {}
      // O chamador registra a falha uma única vez com o contexto correto
      // (inicialização, troca, agendamento ou recuperação).
      Error.throwWithStackTrace(error, stackTrace);
    }
    _notify();
  }

  Future<void> switchSource(VideoSourceConfig config) async {
    _error = null;
    _resetEventState();
    sourceConfig = config;
    _notify();
    try {
      await _enqueueTransition(() async {
        await _stopSourceUnlocked();
        if (!_disposed &&
            (!_suspended || _backgroundMonitoringEnabled) &&
            _baseReady &&
            _scheduleActive) {
          await _startSourceUnlocked(config);
        }
      });
      unawaited(_persistRuntime());
    } catch (error, stackTrace) {
      _error =
          'Falha ao trocar a câmera. Consulte a Central de Erros para os detalhes.';
      unawaited(
        _logs.recordException(
          source: 'Troca de fonte',
          error: error,
          stackTrace: stackTrace,
          message: 'Falha ao trocar a fonte de vídeo.',
          context: _diagnosticContext(),
        ),
      );
      _notify();
    }
  }

  Future<void> _onFrame(RgbFrame frame) async {
    if (_disposed) return;
    final receivedAt = DateTime.now();
    _lastFrameReceivedAt = receivedAt;
    _lastFrameWidth = frame.width;
    _lastFrameHeight = frame.height;
    final rawDelay = receivedAt.difference(frame.capturedAt).inMilliseconds;
    _lastFrameDelayMs = rawDelay < 0 ? 0 : rawDelay;
    _framesReceived++;
    final previousReceived = _lastReceivedFpsSample;
    if (previousReceived != null) {
      final elapsedMs = receivedAt.difference(previousReceived).inMilliseconds;
      if (elapsedMs > 0) {
        final instant = 1000 / elapsedMs;
        _receivedFps = _receivedFps == 0
            ? instant
            : (_receivedFps * 0.82 + instant * 0.18);
      }
    }
    _lastReceivedFpsSample = receivedAt;
    if (_lanStream.running) {
      unawaited(_lanStream.publishFrame(frame));
    }
    if (_processing || !_baseReady || !_detector.isReady) {
      _framesDropped++;
      _framesDroppedProcessing++;
      _notify();
      return;
    }
    if (_backgroundMonitoringEnabled) {
      final lastUpdate = _lastNotificationUpdateAt;
      if (lastUpdate == null ||
          frame.capturedAt.difference(lastUpdate) >= const Duration(seconds: 5)) {
        _lastNotificationUpdateAt = frame.capturedAt;
        unawaited(
          BackgroundMonitorService.updateStatus(
            _appInBackground
                ? 'App minimizado • câmera e IA recebendo imagens.'
                : 'Monitoramento ativo • câmera e IA recebendo imagens.',
          ),
        );
      }
    }
    if (_clipRecordingEnabled) _clipRecorder.pushFrame(frame);
    _health
      ..source = _sourceDisplayName
      ..monitoringActive = true
      ..cameraActive = true
      ..aiReady = _detector.isReady
      ..backgroundActive = _backgroundMonitoringEnabled
      ..updateFrame(receivedAt, _fps);
    if (_settings.cameraIntegrityEnabled) {
      final integrity = _cameraIntegrity.evaluate(frame, frame.capturedAt);
      if (integrity.issue != null) {
        unawaited(_handleCameraIntegrityIssue(frame, integrity.issue!));
      }
    }

    _previewAspectRatio = frame.width / frame.height;
    final processingWatch = Stopwatch()..start();
    final inferenceWatch = Stopwatch();
    final postprocessWatch = Stopwatch();
    var pipelineMeasured = false;
    var auxiliaryInferenceMs = 0.0;
    var detectorRuns = 0;
    var auxiliaryInferenceRuns = 0;
    final session = _frameSession;
    final activeZones = activeMonitoringZones;
    final analysisZone = activeZones.isEmpty
        ? const MonitoringZone.fullFrame()
        : MonitoringZoneService.boundingZone(
            activeZones.map((profile) => profile.zone),
          );
    final analysisFrame = analysisZone.isFullFrame
        ? frame
        : MonitoringZoneService.crop(frame, analysisZone);
    _lastAnalysisWidth = analysisFrame.width;
    _lastAnalysisHeight = analysisFrame.height;
    final processingDone = Completer<void>();
    _processingDone = processingDone;
    _processing = true;
    _notify();

    try {
      final motionResult = _motion.analyze(analysisFrame);
      _motionScore = motionResult.changedRatio;
      _cameraMotion = _settings.motionOnly && motionResult.cameraMotion;
      _motionActive = !_settings.motionOnly || motionResult.hasMotion;
      final now = DateTime.now();

      const idlePresenceRefresh = Duration(milliseconds: 800);
      if (_settings.motionOnly && !motionResult.hasMotion) {
        final lastIdle = _lastIdleInferenceAt;
        if (lastIdle != null && now.difference(lastIdle) < idlePresenceRefresh) {
          // Mantém a última presença confirmada entre verificações silenciosas.
          // Isso evita que uma pessoa/animal parado desapareça só porque o
          // filtro de movimento deixou de disparar.
          _framesDropped++;
          _framesSkippedOptimization++;
          return;
        }
        _lastIdleInferenceAt = now;
      } else {
        _lastIdleInferenceAt = now;
      }

      final previousDetections = _detections;
      final analysisStartedAt = DateTime.now();
      _framesAnalyzed++;
      final previousAnalyzed = _lastAnalyzedFpsSample;
      if (previousAnalyzed != null) {
        final elapsedMs = analysisStartedAt.difference(previousAnalyzed).inMilliseconds;
        if (elapsedMs > 0) {
          final instant = 1000 / elapsedMs;
          _fps = _fps == 0 ? instant : (_fps * 0.82 + instant * 0.18);
        }
      }
      _lastAnalyzedFpsSample = analysisStartedAt;
      _lastPreprocessMs = processingWatch.elapsedMicroseconds / 1000.0;
      _lastPrimaryInferenceMs = null;
      _lastAuxiliaryInferenceMs = 0;
      _lastPostprocessMs = null;
      _lastDetectorRuns = 0;
      _lastAuxiliaryInferenceRuns = 0;
      pipelineMeasured = true;
      inferenceWatch.start();
      final candidateThreshold =
          DetectionConfidencePolicy.candidateThreshold(_settings.confidenceThreshold);
      final primaryWatch = Stopwatch()..start();
      detectorRuns = 1;
      final bikeApproachDetectionActive =
          _bikeConfig.enabled && _bikeConfig.approachAlertsEnabled;
      final primaryAllowedLabels = bikeApproachDetectionActive
          ? <String>{..._alertLabels, ...ObjectFilterCatalog.vehicles}
          : _alertLabels;
      final primaryMaxResults = bikeApproachDetectionActive
          ? math.max(_settings.maxResults, 8).toInt()
          : _settings.maxResults;
      final primaryDetected = await _detector.detect(
        analysisFrame,
        threshold: candidateThreshold,
        maxResults: primaryMaxResults,
        allowedLabels: primaryAllowedLabels,
      );
      primaryWatch.stop();
      _lastPrimaryInferenceMs = primaryWatch.elapsedMicroseconds / 1000.0;
      if (_shouldDiscardFrameResult(session)) return;

      var candidates = ObjectFilterPolicy.apply(primaryDetected, _alertLabels);
      final bikePrimaryCandidates = ObjectFilterPolicy.apply(
        primaryDetected,
        ObjectFilterCatalog.vehicles,
      );
      final primaryGlobalForBike = analysisZone.isFullFrame
          ? bikePrimaryCandidates
          : bikePrimaryCandidates
              .map(
                (item) => MonitoringZoneService.remapDetection(
                  item,
                  analysisZone,
                ),
              )
              .toList(growable: false);
      _updateBikeApproachFastPath(primaryGlobalForBike, now);

      var hasUsefulPrimary = candidates.any(
        (item) => DetectionConfidencePolicy.isCandidate(
          item,
          _settings.confidenceThreshold,
        ),
      );
      var auxiliaryInferenceUsed = false;

      // Movimento separado em componentes evita que dois objetos distantes
      // virem um único recorte gigante. Tenta no máximo duas regiões e para
      // assim que uma delas recuperar uma detecção útil.
      if (motionResult.hasMotion && !hasUsefulPrimary) {
        final focusBoxes = motionResult.focusRegions(maxRegions: 2);
        for (final focusBox in focusBoxes) {
          final focusZone = MonitoringZone(
            xMin: focusBox.xMin,
            yMin: focusBox.yMin,
            xMax: focusBox.xMax,
            yMax: focusBox.yMax,
          );
          final focusedFrame = MonitoringZoneService.crop(analysisFrame, focusZone);
          final auxiliaryWatch = Stopwatch()..start();
          final focusedDetected = await _detector.detect(
            focusedFrame,
            threshold: candidateThreshold,
            maxResults: _settings.maxResults,
            allowedLabels: _alertLabels,
          );
          auxiliaryWatch.stop();
          auxiliaryInferenceMs += auxiliaryWatch.elapsedMicroseconds / 1000.0;
          auxiliaryInferenceRuns++;
          detectorRuns++;
          if (_shouldDiscardFrameResult(session)) return;
          final focusedCandidates = ObjectFilterPolicy
              .apply(focusedDetected, _alertLabels)
              .map((item) => MonitoringZoneService.remapDetection(item, focusZone));
          candidates = DetectionMerger.merge(candidates, focusedCandidates);
          auxiliaryInferenceUsed = true;
          hasUsefulPrimary = candidates.any(
            (item) => DetectionConfidencePolicy.isCandidate(
              item,
              _settings.confidenceThreshold,
            ),
          );
          if (hasUsefulPrimary) break;
        }
      }

      // Reaquisição/multiescala controlada. Quando um objeto recém-visível
      // some ou a cena só possui candidatos pequenos/fracos, roda um único
      // recorte extra a cada ~1,6 s. Isso aumenta a resolução efetiva sem
      // multiplicar continuamente o custo do detector.
      const detailScanInterval = Duration(milliseconds: 1600);
      final lastDetailScan = _lastDetailScanAt;
      final detailScanDue = lastDetailScan == null ||
          now.difference(lastDetailScan) >= detailScanInterval;
      if (!auxiliaryInferenceUsed && detailScanDue) {
        final missingPrevious = analysisZone.isFullFrame
            ? DetectionScanPlanner.missingPriorityDetection(
                previousDetections,
                candidates,
              )
            : null;
        final shouldDetailScan = missingPrevious != null ||
            DetectionScanPlanner.needsDetailScan(
              candidates,
              _settings.confidenceThreshold,
            );
        if (shouldDetailScan) {
          final allowDetailScan = AnalysisBudgetPolicy.allowOptionalDetailScan(
            intervalMs: effectiveAnalysisInterval.inMilliseconds,
            elapsedMs: processingWatch.elapsedMicroseconds / 1000.0,
            estimatedInferenceMs: _lastPrimaryInferenceMs ?? 0,
          );
          if (!allowDetailScan) {
            _detailScansSkippedByBudget++;
            _lastDetailScanAt = now;
          } else {
            late final MonitoringZone detailZone;
            if (missingPrevious != null) {
              detailZone = DetectionScanPlanner.recoveryZone(missingPrevious);
            } else {
              final tiles = DetectionScanPlanner.detailTiles(
                width: analysisFrame.width,
                height: analysisFrame.height,
              );
              detailZone = tiles[_detailTileIndex % tiles.length];
              _detailTileIndex = (_detailTileIndex + 1) % tiles.length;
            }
            final detailFrame = MonitoringZoneService.crop(analysisFrame, detailZone);
            final auxiliaryWatch = Stopwatch()..start();
            final detailDetected = await _detector.detect(
              detailFrame,
              threshold: candidateThreshold,
              maxResults: _settings.maxResults,
              allowedLabels: _alertLabels,
            );
            auxiliaryWatch.stop();
            auxiliaryInferenceMs += auxiliaryWatch.elapsedMicroseconds / 1000.0;
            auxiliaryInferenceRuns++;
            detectorRuns++;
            if (_shouldDiscardFrameResult(session)) return;
            final detailCandidates = ObjectFilterPolicy
                .apply(detailDetected, _alertLabels)
                .map((item) => MonitoringZoneService.remapDetection(item, detailZone));
            candidates = DetectionMerger.merge(candidates, detailCandidates);
            _lastDetailScanAt = now;
          }
        }
      }

      inferenceWatch.stop();
      _lastInferenceMs = inferenceWatch.elapsedMicroseconds / 1000.0;
      _lastAuxiliaryInferenceMs = auxiliaryInferenceMs;
      _lastDetectorRuns = detectorRuns;
      _lastAuxiliaryInferenceRuns = auxiliaryInferenceRuns;
      postprocessWatch.start();

      final selected = _detectionFilter.apply(
        candidates: candidates,
        baseThreshold: _settings.confidenceThreshold,
        now: now,
      );
      final movingSelected = selected
          .where((item) => motionResult.isBoxMoving(item.box))
          .toList(growable: false);
      final selectedGlobal = analysisZone.isFullFrame
          ? selected
          : selected
              .map(
                (item) =>
                    MonitoringZoneService.remapDetection(item, analysisZone),
              )
              .toList(growable: false);
      final movingGlobal = analysisZone.isFullFrame
          ? movingSelected
          : movingSelected
              .map(
                (item) =>
                    MonitoringZoneService.remapDetection(item, analysisZone),
              )
              .toList(growable: false);
      final syntheticPeople = _alertLabels.contains('person')
          ? PartialPersonDetectionService.infer(
              frame,
              motionResult,
              selectedGlobal,
            )
          : const <Detection>[];
      final selectedWithHints = <Detection>[
        ...selectedGlobal,
        ...syntheticPeople,
      ];
      final movingWithHints = <Detection>[
        ...movingGlobal,
        ...syntheticPeople,
      ];
      final zoneFilteredSelected = activeZones.isEmpty
          ? selectedWithHints
          : MonitoringZoneService.filterToZones(
              selectedWithHints,
              activeZones.map((profile) => profile.zone),
            );
      final zoneFilteredMoving = activeZones.isEmpty
          ? movingWithHints
          : MonitoringZoneService.filterToZones(
              movingWithHints,
              activeZones.map((profile) => profile.zone),
            );

      // Movimento passa a ser um gatilho de economia/alerta, não um motivo para
      // apagar uma detecção ainda visível. Isso estabiliza pessoas paradas e
      // veículos/animais que interrompem o movimento por alguns instantes.
      _detections = ObjectAppearanceService.enrichAll(
        frame,
        zoneFilteredSelected,
      );

      if (_error?.startsWith('Falha na detecção') == true) _error = null;

      final tracking = _trackingEnabled
          ? _tracker.update(
              detections: _detections,
              zones: _trackingZones(activeZones),
              now: now,
            )
          : const TrackingResult(
              active: <TrackedDetection>[],
              transitions: <ZoneTransition>[],
            );
      _trackedDetections = tracking.active;
      if (_announceEntryExit && tracking.transitions.isNotEmpty) {
        unawaited(_recordTransitions(frame, tracking.transitions));
      }

      bool isMovingDetection(Detection detection) => zoneFilteredMoving.any(
            (moving) => _sameDetectionRegion(detection, moving),
          );
      for (final tracked in _trackedDetections) {
        if (isMovingDetection(tracked.detection)) {
          _recentMotionByTrackId[tracked.trackId] = now;
        }
      }
      _recentMotionByTrackId.removeWhere(
        (_, lastMotion) =>
            now.difference(lastMotion) > const Duration(milliseconds: 1400),
      );

      final visibleLabels = zoneFilteredSelected.map((item) => item.label).toSet();
      final movingLabels = <String>{...zoneFilteredMoving.map((item) => item.label)};
      for (final tracked in _trackedDetections) {
        if (_recentMotionByTrackId.containsKey(tracked.trackId)) {
          movingLabels.add(tracked.detection.label);
        }
      }
      final ruleEligibleLabels = _smartRuleEngine.evaluate(
        visibleLabels: visibleLabels,
        movingLabels: movingLabels,
        now: now,
      );
      final alertTargets = <String, Detection>{};
      for (final detection in _detections) {
        if (!ruleEligibleLabels.contains(detection.label)) continue;
        final tracked = _trackedDetections
            .where((item) => identical(item.detection, detection))
            .firstOrNull;
        if (_settings.motionOnly) {
          final recentlyMoved = tracked != null
              ? _recentMotionByTrackId.containsKey(tracked.trackId)
              : isMovingDetection(detection);
          if (!recentlyMoved) continue;
        }
        final groupKey =
            ObjectFilterCatalog.groupKeyForLabel(detection.label) ?? detection.label;
        final key = tracked == null
            ? groupKey
            : '$groupKey#${tracked.trackId}';
        final existing = alertTargets[key];
        if (existing == null || detection.confidence > existing.confidence) {
          alertTargets[key] = detection;
        }
      }
      final alerts = _alertGuard.evaluate(alertTargets.keys.toSet(), now);
      if (alerts.isNotEmpty) {
        unawaited(_recordConfirmedEvents(frame, alerts, alertTargets));
      }
      postprocessWatch.stop();
      _lastPostprocessMs = postprocessWatch.elapsedMicroseconds / 1000.0;
    } catch (error, stackTrace) {
      if (_isExpectedDetectionCancellation(error, session)) return;
      _error = 'Falha na detecção. O detalhe foi salvo na Central de Erros.';
      unawaited(
        _logs.recordException(
          source: 'Detecção',
          error: error,
          stackTrace: stackTrace,
          message: 'Falha ao analisar um frame.',
          context: <String, Object?>{
            ..._diagnosticContext(),
            'frame': '${frame.width}x${frame.height}',
            'frameAnalisado': '${analysisFrame.width}x${analysisFrame.height}',
            'movimento': _motionScore.toStringAsFixed(3),
          },
        ),
      );
    } finally {
      if (inferenceWatch.isRunning) {
        inferenceWatch.stop();
        if (inferenceWatch.elapsedMicroseconds > 0) {
          _lastInferenceMs = inferenceWatch.elapsedMicroseconds / 1000.0;
        }
      }
      if (postprocessWatch.isRunning) {
        postprocessWatch.stop();
        _lastPostprocessMs = postprocessWatch.elapsedMicroseconds / 1000.0;
      }
      if (pipelineMeasured) {
        _lastAuxiliaryInferenceMs = auxiliaryInferenceMs;
        _lastDetectorRuns = detectorRuns;
        _lastAuxiliaryInferenceRuns = auxiliaryInferenceRuns;
        processingWatch.stop();
        _lastTotalProcessingMs = processingWatch.elapsedMicroseconds / 1000.0;
        final endToEndUs = DateTime.now().difference(frame.capturedAt).inMicroseconds;
        _lastEndToEndMs = endToEndUs <= 0 ? 0 : endToEndUs / 1000.0;
      }
      _processing = false;
      if (!processingDone.isCompleted) processingDone.complete();
      if (identical(_processingDone, processingDone)) _processingDone = null;
      _notify();
    }
  }

  void _updateBikeApproachFastPath(
    List<Detection> primaryDetections,
    DateTime now,
  ) => this._updateBikeApproachFastPathImpl(primaryDetections, now);

  void _resetBikeApproach() => this._resetBikeApproachImpl();

  bool _sameDetectionRegion(Detection a, Detection b) =>
      this._sameDetectionRegionImpl(a, b);

  List<MonitoringZoneProfile> _trackingZones(
    List<MonitoringZoneProfile> activeZones,
  ) => this._trackingZonesImpl(activeZones);

  Future<void> _recordConfirmedEvents(
    RgbFrame frame,
    List<String> alertKeys,
    Map<String, Detection> alertTargets,
  ) => this._recordConfirmedEventsImpl(frame, alertKeys, alertTargets);

  Future<void> _recordTransitions(
    RgbFrame frame,
    List<ZoneTransition> transitions,
  ) => this._recordTransitionsImpl(frame, transitions);

  String get _sourceDisplayName => this._sourceDisplayNameImpl;

  Future<void> _deliverAlert(
    String message, {
    SpeechPriority priority = SpeechPriority.normal,
    String? audioSlot,
  }) => this._deliverAlertImpl(
        message,
        priority: priority,
        audioSlot: audioSlot,
      );

  Future<void> _handleCameraIntegrityIssue(
    RgbFrame frame,
    CameraIntegrityIssue issue,
  ) => this._handleCameraIntegrityIssueImpl(frame, issue);

  bool _shouldDiscardFrameResult(int session) =>
      _disposed ||
      (_suspended && !_backgroundMonitoringEnabled) ||
      session != _frameSession ||
      !_baseReady;

  bool _isExpectedDetectionCancellation(Object error, int session) {
    if (_shouldDiscardFrameResult(session)) return true;
    final text = error.toString().toLowerCase();
    return (_suspended || _disposed) &&
        (text.contains('detector encerrado') ||
            text.contains('detector nao inicializado') ||
            text.contains('detector não inicializado'));
  }

  Future<void> _waitForProcessing() async {
    final done = _processingDone;
    if (done == null || done.isCompleted) return;
    try {
      await done.future.timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  void setVoiceEnabled(bool enabled) {
    _speech.setEnabled(enabled);
    _settings = _settings.copyWith(
      voiceEnabled: enabled,
      alertOutputs: _settings.alertOutputs.copyWith(voice: enabled),
    );
    unawaited(_persistRuntime());
    _notify();
  }

  void setClipOptions(Duration duration, ClipFormatPreference format) {
    final normalized = Duration(seconds: duration.inSeconds.clamp(3, 20).toInt());
    _settings = _settings.copyWith(clipDuration: normalized, clipFormatPreference: format);
    _clipRecorder.configure(clipDuration: normalized, format: format);
    unawaited(_persistRuntime());
    _notify();
  }

  void setCameraIntegrityEnabled(bool enabled) {
    _settings = _settings.copyWith(cameraIntegrityEnabled: enabled);
    _cameraIntegrity.reset();
    unawaited(_persistRuntime());
    _notify();
  }

  void setAlertLabels(Set<String> labels) {
    if (labels.isEmpty) return;
    final next = <String>{...labels};
    if (next.length == _alertLabels.length && next.containsAll(_alertLabels)) {
      return;
    }
    _alertLabels = next;
    _settings = _settings.copyWith(alertLabels: Set<String>.unmodifiable(next));
    _detections = ObjectFilterPolicy.apply(_detections, _alertLabels);
    _resetRulesAndTracking();
    _notify();
    unawaited(_persistRuntime());
    unawaited(
      _logs.record(
        level: ErrorLogLevel.info,
        source: 'Filtro de objetos',
        message: 'Objetos monitorados atualizados.',
        context: <String, Object?>{
          'grupos': ObjectFilterCatalog.groupKeysForSelection(_alertLabels)
              .map((key) => switch (key) {
                    'person' => 'Pessoas',
                    'vehicle' => 'Automóveis',
                    'animal' => 'Animais',
                    _ => key,
                  })
              .toList()
            ..sort(),
        },
      ),
    );
  }

  void setSmartAlertRules(SmartAlertRules rules) {
    _smartAlertRules = rules;
    _settings = _settings.copyWith(smartAlertRules: rules);
    if (_baseReady) {
      _smartRuleEngine.updateRules(rules);
      _alertGuard.reset();
    }
    _tracker.reset();
    _notify();
    unawaited(_persistRuntime());
    unawaited(
      _logs.record(
        level: ErrorLogLevel.info,
        source: 'Regras inteligentes',
        message: rules.enabled
            ? 'Regras inteligentes de alerta atualizadas.'
            : 'Regras inteligentes de alerta desativadas.',
        context: _smartRulesDiagnosticContext(),
      ),
    );
  }

  void setMonitoringZones(List<MonitoringZoneProfile> zones) {
    final normalized = zones
        .take(6)
        .map((item) => item.copyWith(zone: item.zone.normalized()))
        .toList(growable: true);
    _monitoringZones = normalized.isEmpty
        ? <MonitoringZoneProfile>[const MonitoringZoneProfile.primary()]
        : normalized;
    _settings = _settings.copyWith(
      monitoringZones: List<MonitoringZoneProfile>.unmodifiable(_monitoringZones),
    );
    _resetAfterZoneChange();
    unawaited(_persistRuntime());
  }

  void updateMonitoringZone(String id, MonitoringZone zone) {
    final index = _monitoringZones.indexWhere((item) => item.id == id);
    if (index < 0) return;
    _monitoringZones[index] = _monitoringZones[index].copyWith(
      zone: zone.normalized(),
      enabled: true,
    );
    setMonitoringZones(_monitoringZones);
  }

  void setMonitoringZoneEnabled(String id, bool enabled) {
    final index = _monitoringZones.indexWhere((item) => item.id == id);
    if (index < 0) return;
    _monitoringZones[index] = _monitoringZones[index].copyWith(enabled: enabled);
    setMonitoringZones(_monitoringZones);
  }

  String addMonitoringZone({String? name}) {
    final id = 'zona_${DateTime.now().microsecondsSinceEpoch}';
    final nextNumber = _monitoringZones.length + 1;
    _monitoringZones.add(
      MonitoringZoneProfile(
        id: id,
        name: name ?? 'Área $nextNumber',
        zone: const MonitoringZone(
          xMin: 0.2,
          yMin: 0.2,
          xMax: 0.8,
          yMax: 0.8,
        ),
      ),
    );
    setMonitoringZones(_monitoringZones);
    return id;
  }

  void removeMonitoringZone(String id) {
    _monitoringZones.removeWhere((item) => item.id == id);
    setMonitoringZones(_monitoringZones);
  }

  void renameMonitoringZone(String id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final index = _monitoringZones.indexWhere((item) => item.id == id);
    if (index < 0) return;
    _monitoringZones[index] = _monitoringZones[index].copyWith(name: trimmed);
    setMonitoringZones(_monitoringZones);
  }

  Future<bool> _ensureBackgroundService({String? statusText}) async {
    if (!_backgroundMonitoringEnabled || _disposed) return false;
    final started = await BackgroundMonitorService.acquire(
      owner: BackgroundMonitorService.monitorOwner,
      usesCamera: sourceConfig.type == VideoSourceType.localCamera,
      statusText: statusText,
    );
    final status = await BackgroundMonitorService.status();
    _health.backgroundActive = started && status.flutterHeartbeatFresh;
    return started;
  }

  void _startBackgroundHealthTimer() {
    _backgroundHealthTimer?.cancel();
    _backgroundHealthTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_checkBackgroundHealth()),
    );
  }

  Future<void> _checkBackgroundHealth() async {
    if (_disposed || !_backgroundMonitoringEnabled || !_baseReady) return;
    final status = await BackgroundMonitorService.status();
    _health.backgroundActive = status.running && status.flutterHeartbeatFresh;
    if (!status.running) {
      if (!_appInBackground) {
        await _ensureBackgroundService(
          statusText: 'Monitoramento ativo • restaurando serviço…',
        );
      } else {
        _health.markCameraWarning(CameraHealthState.offline);
      }
      return;
    }
    if (!_scheduleActive || _sourceStatus.state == VideoSourceState.connecting) {
      return;
    }
    final last = _lastFrameReceivedAt;
    final staleAfter = Duration(
      milliseconds: (effectiveAnalysisInterval.inMilliseconds * 4)
          .clamp(4000, 8000)
          .toInt(),
    );
    final stale = last == null || DateTime.now().difference(last) > staleAfter;
    if (!stale) return;

    _health.markCameraWarning(CameraHealthState.offline);
    await BackgroundMonitorService.updateStatus(
      'Serviço ativo • câmera sem imagens recentes; tentando recuperar.',
    );
    if (_backgroundRecoveryInProgress) return;
    final previousAttempt = _lastRecoveryAttemptAt;
    if (previousAttempt != null &&
        DateTime.now().difference(previousAttempt) < const Duration(seconds: 12)) {
      return;
    }
    _lastRecoveryAttemptAt = DateTime.now();
    _backgroundRecoveryInProgress = true;
    try {
      if (sourceConfig.type == VideoSourceType.localCamera) {
        await SharedLocalCameraService.instance.restartPipeline();
      } else {
        await _enqueueTransition(() async {
          if (_disposed || !_backgroundMonitoringEnabled || !_scheduleActive) return;
          await _stopSourceUnlocked();
          await _startSourceUnlocked(sourceConfig);
        });
      }
    } catch (error, stackTrace) {
      unawaited(
        _logs.recordException(
          source: 'Segundo plano',
          error: error,
          stackTrace: stackTrace,
          message: 'A câmera deixou de entregar quadros e a recuperação automática falhou.',
          level: ErrorLogLevel.warning,
          context: _diagnosticContext(),
        ),
      );
    } finally {
      _backgroundRecoveryInProgress = false;
    }
  }

  Future<bool> setBackgroundMonitoringEnabled(bool enabled) async {
    if (_backgroundMonitoringEnabled == enabled) return enabled;
    if (enabled) {
      if (sourceConfig.type == VideoSourceType.localCamera) {
        final cameraGranted = await _native.requestCameraPermission();
        if (!cameraGranted) return false;
      }
      await _native.requestNotificationPermission();
      _backgroundMonitoringEnabled = true;
      final started = await _ensureBackgroundService(
        statusText: 'Monitoramento ativo • preparando segundo plano.',
      );
      if (!started) {
        _backgroundMonitoringEnabled = false;
        _health.backgroundActive = false;
        unawaited(
          _logs.record(
            level: ErrorLogLevel.warning,
            source: 'Segundo plano',
            message: 'O Android recusou iniciar o serviço de monitoramento.',
          ),
        );
        return false;
      }
    } else {
      _backgroundMonitoringEnabled = false;
      _health.backgroundActive = false;
      await BackgroundMonitorService.release(BackgroundMonitorService.monitorOwner);
    }
    _settings = _settings.copyWith(backgroundMonitoringEnabled: enabled);
    _notify();
    unawaited(_persistRuntime());
    return enabled;
  }

  void setClipRecordingEnabled(bool enabled) {
    _clipRecordingEnabled = enabled;
    _settings = _settings.copyWith(clipRecordingEnabled: enabled);
    if (!enabled) unawaited(_clipRecorder.flushPending());
    _notify();
    unawaited(_persistRuntime());
  }

  void setTrackingEnabled(bool enabled) {
    _trackingEnabled = enabled;
    _settings = _settings.copyWith(trackingEnabled: enabled);
    _tracker.reset();
    _detectionFilter.reset();
    _recentMotionByTrackId.clear();
    _lastIdleInferenceAt = null;
    _lastDetailScanAt = null;
    _detailTileIndex = 0;
    _seenTrackIds.clear();
    _lastTransitionSpeechAt.clear();
    _trackedDetections = const <TrackedDetection>[];
    _notify();
    unawaited(_persistRuntime());
  }

  void setAnnounceEntryExit(bool enabled) {
    _announceEntryExit = enabled;
    _settings = _settings.copyWith(announceEntryExit: enabled);
    _notify();
    unawaited(_persistRuntime());
  }

  void setSchedule(MonitorSchedule schedule) {
    _schedule = schedule;
    _settings = _settings.copyWith(schedule: schedule);
    unawaited(_persistRuntime());
    unawaited(_applyScheduleState());
    _notify();
  }

  void _resetSessionMetrics() => this._resetSessionMetricsImpl();

  void _resetAfterZoneChange() => this._resetAfterZoneChangeImpl();

  void _resetRulesAndTracking() => this._resetRulesAndTrackingImpl();

  void _resetEventState() => this._resetEventStateImpl();

  Future<void> suspend() async {
    _appInBackground = true;
    if (_backgroundMonitoringEnabled) {
      await BackgroundMonitorService.updateStatus(
        'App minimizado • monitoramento continua ativo.',
      );
      return;
    }
    _suspended = true;
    _frameSession++;
    await _enqueueTransition(_stopSourceUnlocked);
  }

  Future<void> resume() async {
    _appInBackground = false;
    _suspended = false;
    if (_disposed || _initializing || !_baseReady) return;
    if (_backgroundMonitoringEnabled) {
      await _ensureBackgroundService(
        statusText: 'Monitoramento ativo • Vigia IA em primeiro plano.',
      );
    }
    await _applyScheduleState();
    await _checkBackgroundHealth();
  }

  Future<void> _stopSourceUnlocked() async {
    _frameSession++;
    _motion.reset();
    if (_baseReady) _smartRuleEngine.reset();
    _tracker.reset();
    _resetBikeApproach();
    _motionActive = false;
    _cameraMotion = false;
    _motionScore = 0;
    _detections = const [];
    _trackedDetections = const <TrackedDetection>[];
    _previewAspectRatio = null;
    _lastFrameReceivedAt = null;
    await _frameSubscription?.cancel();
    _frameSubscription = null;
    await _statusSubscription?.cancel();
    _statusSubscription = null;
    await _clipRecorder.flushPending();
    await _lanStream.stop();
    _lanPermissionError = null;
    _health.updateLan(active: false, clients: 0);

    final source = _source;
    if (source is RemotePhoneCameraSource) {
      source.remoteStatusNotifier.removeListener(_onRemotePhoneStatusChanged);
    }
    _source = null;
    await _native.setBikeScreenBrightness(null);
    _sourceStatus = const VideoSourceStatus(VideoSourceState.stopped);
    _health.stopMonitoring();
    _health.aiReady = _detector.isReady;
    _notify();
    if (source == null) return;

    await Future<void>.delayed(const Duration(milliseconds: 50));
    try {
      await source.dispose();
    } catch (error, stackTrace) {
      unawaited(
        _logs.recordException(
          source: 'Liberação de vídeo',
          error: error,
          stackTrace: stackTrace,
          message: 'Falha não fatal ao liberar a fonte de vídeo.',
          context: _diagnosticContext(),
          level: ErrorLogLevel.warning,
        ),
      );
    }
  }

  Future<void> _enqueueTransition(Future<void> Function() operation) {
    final completer = Completer<void>();
    final previous = _transitionTail;
    _transitionTail = () async {
      try {
        await previous;
      } catch (_) {}
      try {
        await operation();
        if (!completer.isCompleted) completer.complete();
      } catch (error, stackTrace) {
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      }
    }();
    return completer.future;
  }

  Future<void> _persistRuntime() => _appSettings.updateRuntime(
        source: sourceConfig,
        settings: _runtimeSettings(),
      );

  MonitorSettings _runtimeSettings() => _settings.copyWith(
        alertLabels: Set<String>.unmodifiable(_alertLabels),
        monitoringZones:
            List<MonitoringZoneProfile>.unmodifiable(_monitoringZones),
        smartAlertRules: _smartAlertRules,
        clipRecordingEnabled: _clipRecordingEnabled,
        trackingEnabled: _trackingEnabled,
        announceEntryExit: _announceEntryExit,
        backgroundMonitoringEnabled: _backgroundMonitoringEnabled,
        voiceEnabled: _settings.alertOutputs.voice,
        alertOutputs: _settings.alertOutputs.copyWith(voice: _settings.alertOutputs.voice),
        schedule: _schedule,
      );

  Map<String, Object?> _zonesDiagnosticContext() =>
      this._zonesDiagnosticContextImpl();

  Map<String, Object?> _smartRulesDiagnosticContext() =>
      this._smartRulesDiagnosticContextImpl();

  Map<String, Object?> _diagnosticContext() => this._diagnosticContextImpl();

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _suspended = true;
    _scheduleTimer?.cancel();
    _backgroundHealthTimer?.cancel();
    _bikeTelemetryTimer?.cancel();
    _sessionTelemetryTimer?.cancel();
    _bikeMode.removeListener(_onBikeModeChanged);
    _lanStream.removeListener(_onLanStreamChanged);
    unawaited(_disposeAsync());
    super.dispose();
  }

  Future<void> _disposeAsync() async {
    await _enqueueTransition(_stopSourceUnlocked);
    await _waitForProcessing();
    await _clipRecorder.flushPending();
    await BackgroundMonitorService.release(BackgroundMonitorService.monitorOwner);
    await _native.setBikeScreenBrightness(null);
    await _detector.dispose();
    await _speech.dispose();
  }
}

class _RecentAlertMemory {
  const _RecentAlertMemory({
    required this.group,
    required this.timestamp,
    required this.box,
    required this.appearance,
    required this.trackId,
  });

  final String group;
  final DateTime timestamp;
  final NormalizedBox box;
  final ObjectAppearance? appearance;
  final int? trackId;

  _RecentAlertMemory copyWith({
    DateTime? timestamp,
    NormalizedBox? box,
    ObjectAppearance? appearance,
    int? trackId,
  }) =>
      _RecentAlertMemory(
        group: group,
        timestamp: timestamp ?? this.timestamp,
        box: box ?? this.box,
        appearance: appearance ?? this.appearance,
        trackId: trackId ?? this.trackId,
      );
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
