import 'dart:async';

import '../models/alert_preferences.dart';
import 'detection_cadence_policy.dart';
import 'native_platform_service.dart';
import 'performance_telemetry_service.dart';
import 'speech_service.dart';

/// Coordena arquivo e TTS no mesmo fluxo, mantendo só o próximo aviso atual.
class AlertVoiceService {
  AlertVoiceService({SpeechService? speech,
    Future<bool> Function(String, int, DateTime?)? playAudio,
    Future<void> Function()? stopAudio,
    Future<Map<String, Object?>> Function()? audioDiagnostics,
  }) : _speech = speech ?? SpeechService(),
       _playAudio = playAudio ?? ((slot, priority, capturedAt) =>
           NativePlatformService.instance.playCustomAlertAudio(slot,
             priority: priority, capturedAt: capturedAt)),
       _stopAudio = stopAudio ?? NativePlatformService.instance.stopAlertAudio,
       _audioDiagnostics = audioDiagnostics ??
           (playAudio == null
               ? NativePlatformService.instance.audioDiagnostics
               : () async => const <String, Object?>{});

  final SpeechService _speech;
  final Future<bool> Function(String, int, DateTime?) _playAudio;
  final Future<void> Function() _stopAudio;
  final Future<Map<String, Object?>> Function() _audioDiagnostics;
  _VoiceRequest? _active;
  _VoiceRequest? _pending;
  int _generation = 0;
  VoiceAlertPreferences _preferences = const VoiceAlertPreferences();

  bool get enabled => _speech.enabled;
  bool get languageInstalled => _speech.languageInstalled;
  Future<void> initialize() => _speech.initialize();

  void configure(VoiceAlertPreferences preferences) {
    _preferences = preferences;
  }

  void setEnabled(bool enabled) {
    _speech.setEnabled(enabled);
    if (!enabled) unawaited(stop());
  }

  Future<void> deliver(String text, {String? audioSlot,
    SpeechPriority priority = SpeechPriority.normal, DateTime? capturedAt}) {
    if (!enabled) return Future<void>.value();
    if (audioSlot != null && !_preferences.allowsSlot(audioSlot)) {
      _trace(_VoiceRequest(text, audioSlot, priority, capturedAt), 'suppressed_by_user');
      return Future<void>.value();
    }
    if (audioSlot == null && !_preferences.dynamicTtsEnabled) {
      _trace(_VoiceRequest(text, audioSlot, priority, capturedAt), 'dynamic_tts_disabled');
      return Future<void>.value();
    }
    final request = _VoiceRequest(text, audioSlot, priority, capturedAt);
    final active = _active;
    if (active != null) {
      if (active.priority == SpeechPriority.high && priority == SpeechPriority.normal) {
        _trace(request, 'suppressed_priority');
        return Future<void>.value();
      }
      if (priority == SpeechPriority.normal) {
        _pending?.complete();
        _pending = request;
        _trace(request, 'queued_latest');
        return request.done.future;
      }
      _pending?.complete();
      _pending = null;
      active.complete();
    }
    _active = request;
    unawaited(_play(request, ++_generation, interrupt: active != null));
    return request.done.future;
  }

  Future<void> _play(_VoiceRequest request, int generation, {bool interrupt = false}) async {
    bool current() => enabled && generation == _generation;
    bool fresh() => request.capturedAt == null || DetectionCadencePolicy.fresh(
        request.capturedAt!, DateTime.now(), DetectionCadencePolicy.spokenFrameMaxAge);
    try {
      if (interrupt || (request.audioSlot == null && request.priority == SpeechPriority.high)) {
        await _stopAudio();
        await _speech.stop();
      }
      if (!current() || !fresh() ||
          DateTime.now().difference(request.queuedAt) > const Duration(seconds: 3)) {
        _trace(request, 'expired_or_cancelled');
        return;
      }
      _trace(request, 'requested');
      final handled = request.audioSlot != null && await _playAudio(
        request.audioSlot!, request.priority == SpeechPriority.high ? 2 : 0,
        request.capturedAt,
      );
      if (handled) {
        final diagnostics = await _audioDiagnostics();
        _trace(request, 'native_handled', diagnostics: diagnostics);
      } else if (!current() || !fresh()) {
        _trace(request, 'cancelled_or_expired_before_tts');
      } else if (request.audioSlot != null && !_preferences.ttsFallbackEnabled) {
        final diagnostics = await _audioDiagnostics();
        _trace(request, 'native_failed_tts_disabled', diagnostics: diagnostics);
      } else if (!languageInstalled) {
        final diagnostics = await _audioDiagnostics();
        _trace(request, 'tts_unavailable', diagnostics: diagnostics);
      } else {
        final diagnostics = await _audioDiagnostics();
        _trace(request, request.audioSlot == null ? 'dynamic_tts_requested' : 'native_failed_tts_requested', diagnostics: diagnostics);
        await _speech.speakMessage(request.text, priority: request.priority);
        _trace(request, 'tts_returned');
      }
    } catch (error) {
      _trace(request, 'delivery_error:$error');
    } finally {
      request.complete();
      if (generation == _generation) {
        _active = null;
        final next = _pending;
        _pending = null;
        if (next != null && enabled) {
          _active = next;
          unawaited(_play(next, ++_generation));
        } else { next?.complete(); }
      }
    }
  }

  void _trace(
    _VoiceRequest request,
    String event, {
    Map<String, Object?> diagnostics = const <String, Object?>{},
  }) {
    PerformanceTelemetryService.instance.recordAlertEvent({
      'timestamp': DateTime.now().toIso8601String(), 'event': event,
      'slot': request.audioSlot, 'priority': request.priority.name,
      'frameCapturedAt': request.capturedAt?.toIso8601String(),
      if (diagnostics.isNotEmpty) ...<String, Object?>{
        'audioState': diagnostics['state'],
        'audioErrorCode': diagnostics['lastErrorCode'],
        'audioError': diagnostics['lastError'],
        'audioErrorPhase': diagnostics['lastErrorPhase'],
        'audioSource': diagnostics['lastSource'],
        'audioFocus': diagnostics['lastFocusResultName'],
        'audioUsedFallback': diagnostics['lastPlaybackUsedFallback'],
        'audioFallbackReason': diagnostics['lastFallbackReason'],
        'mediaVolume': diagnostics['mediaVolume'],
        'mediaMaxVolume': diagnostics['mediaMaxVolume'],
        'mediaMuted': diagnostics['mediaMuted'],
      },
    });
  }

  Future<void> stop() async {
    _generation++;
    _active?.complete(); _active = null;
    _pending?.complete(); _pending = null;
    await _stopAudio();
    await _speech.stop();
  }

  Future<void> dispose() async {
    setEnabled(false);
    await stop();
    await _speech.dispose();
  }
}

class _VoiceRequest {
  _VoiceRequest(this.text, this.audioSlot, this.priority, this.capturedAt);
  final String text;
  final String? audioSlot;
  final SpeechPriority priority;
  final DateTime? capturedAt;
  final DateTime queuedAt = DateTime.now();
  final Completer<void> done = Completer<void>();
  void complete() { if (!done.isCompleted) done.complete(); }
}
