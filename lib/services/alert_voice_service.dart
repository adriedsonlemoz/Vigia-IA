import 'dart:async';

import 'detection_cadence_policy.dart';
import 'native_platform_service.dart';
import 'performance_telemetry_service.dart';
import 'speech_service.dart';

/// Coordena arquivo e TTS no mesmo fluxo, mantendo só o próximo aviso atual.
class AlertVoiceService {
  AlertVoiceService({SpeechService? speech,
    Future<bool> Function(String, int, DateTime?)? playAudio,
    Future<void> Function()? stopAudio,
  }) : _speech = speech ?? SpeechService(),
       _playAudio = playAudio ?? ((slot, priority, capturedAt) =>
           NativePlatformService.instance.playCustomAlertAudio(slot,
             priority: priority, capturedAt: capturedAt)),
       _stopAudio = stopAudio ?? NativePlatformService.instance.stopAlertAudio;

  final SpeechService _speech;
  final Future<bool> Function(String, int, DateTime?) _playAudio;
  final Future<void> Function() _stopAudio;
  _VoiceRequest? _active;
  _VoiceRequest? _pending;
  int _generation = 0;

  bool get enabled => _speech.enabled;
  bool get languageInstalled => _speech.languageInstalled;
  Future<void> initialize() => _speech.initialize();

  void setEnabled(bool enabled) {
    _speech.setEnabled(enabled);
    if (!enabled) unawaited(stop());
  }

  Future<void> deliver(String text, {String? audioSlot,
    SpeechPriority priority = SpeechPriority.normal, DateTime? capturedAt}) {
    if (!enabled) return Future<void>.value();
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
        _trace(request, 'native_handled');
      } else if (!current() || !fresh()) {
        _trace(request, 'cancelled_or_expired_before_tts');
      } else if (!languageInstalled) {
        _trace(request, 'tts_unavailable');
      } else {
        _trace(request, 'tts_requested');
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

  void _trace(_VoiceRequest request, String event) {
    PerformanceTelemetryService.instance.recordAlertEvent({
      'timestamp': DateTime.now().toIso8601String(), 'event': event,
      'slot': request.audioSlot, 'priority': request.priority.name,
      'frameCapturedAt': request.capturedAt?.toIso8601String(),
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
