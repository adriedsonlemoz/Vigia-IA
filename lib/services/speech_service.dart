import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'performance_telemetry_service.dart';

enum SpeechPriority { normal, high }

class SpeechService {
  static const Duration _initializationStepTimeout = Duration(seconds: 3);

  final FlutterTts _tts = FlutterTts();
  bool _enabled = true;
  bool _initialized = false;
  bool _languageInstalled = false;
  String? _lastError;
  int _generation = 0;
  SpeechPriority? _activePriority;
  DateTime? _activeStartedAt;

  bool get enabled => _enabled;
  bool get languageInstalled => _languageInstalled;
  bool get initialized => _initialized;
  String? get lastError => _lastError;

  Future<void> initialize() async {
    if (_initialized) return;
    _tts.setStartHandler(() => _trace('tts_started'));
    _tts.setCompletionHandler(() => _trace('tts_completed'));
    _tts.setCancelHandler(() => _trace('tts_cancelled'));
    _tts.setErrorHandler((message) => _trace('tts_error', '$message'));
    try {
      final installed = await _tts
          .isLanguageInstalled('pt-BR')
          .timeout(_initializationStepTimeout);
      _languageInstalled = installed == true;
      if (_languageInstalled) await _configureEngine();
      _lastError = null;
    } catch (error) {
      _languageInstalled = false;
      _lastError = error.toString();
    } finally {
      _initialized = true;
    }
  }

  Future<void> _configureEngine() async {
    await _tts.setLanguage('pt-BR').timeout(_initializationStepTimeout);
    await _tts.setSpeechRate(0.48).timeout(_initializationStepTimeout);
    await _tts.setVolume(1.0).timeout(_initializationStepTimeout);
    await _tts.setPitch(1.0).timeout(_initializationStepTimeout);
    await _tts.awaitSpeakCompletion(true).timeout(_initializationStepTimeout);
  }

  Future<void> recoverAfterResume() async {
    if (!_initialized) {
      await initialize();
      return;
    }
    try {
      final installed = await _tts
          .isLanguageInstalled('pt-BR')
          .timeout(_initializationStepTimeout);
      _languageInstalled = installed == true;
      if (_languageInstalled) await _configureEngine();
      _lastError = null;
    } catch (error) {
      _languageInstalled = false;
      _lastError = error.toString();
    }
  }

  void setEnabled(bool value) {
    _enabled = value;
    if (!value) {
      _generation++;
      _activePriority = null;
      _activeStartedAt = null;
      unawaited(_tts.stop());
    }
  }

  Future<void> speakDetection(String displayLabel) =>
      speakDetections(<String>[displayLabel]);

  /// Fala sempre o alerta atual, sem manter uma fila FIFO de mensagens antigas.
  /// Um alerta de alta prioridade (entrada/saída ou integridade) não é
  /// interrompido por um alerta genérico disparado logo em seguida.
  Future<void> speakMessage(
    String text, {
    SpeechPriority priority = SpeechPriority.normal,
  }) async {
    final normalized = text.trim();
    if (!_enabled || !_initialized || !_languageInstalled || normalized.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final activeStartedAt = _activeStartedAt;
    if (_activePriority == SpeechPriority.high &&
        priority == SpeechPriority.normal &&
        activeStartedAt != null &&
        now.difference(activeStartedAt) < const Duration(seconds: 5)) {
      return;
    }

    final generation = ++_generation;
    _activePriority = priority;
    _activeStartedAt = now;
    try {
      await _tts.stop();
      if (!_enabled || generation != _generation) return;
      await _tts.speak(normalized);
    } catch (error) {
      _lastError = error.toString();
      // Uma falha pontual do TTS não deve interromper detecções futuras.
    } finally {
      if (generation == _generation) {
        _activePriority = null;
        _activeStartedAt = null;
      }
    }
  }

  Future<void> speakDetections(Iterable<String> displayLabels) async {
    if (!_enabled || !_initialized || !_languageInstalled) return;
    final labels = displayLabels
        .map((label) => label.trim())
        .where((label) => label.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (labels.isEmpty) return;

    final text = labels.length == 1
        ? 'Movimento detectado: ${labels.first}.'
        : 'Movimento detectado: ${_joinLabels(labels)}.';
    await speakMessage(text);
  }

  String _joinLabels(List<String> labels) {
    if (labels.length == 2) return '${labels[0]} e ${labels[1]}';
    return '${labels.sublist(0, labels.length - 1).join(', ')} e ${labels.last}';
  }

  void _trace(String event, [String? error]) {
    PerformanceTelemetryService.instance.recordAlertEvent({
      'timestamp': DateTime.now().toIso8601String(), 'event': event,
      'error': ?error,
    });
  }

  Future<void> stop() async {
    _generation++;
    _activePriority = null;
    _activeStartedAt = null;
    await _tts.stop();
  }

  Future<void> dispose() async {
    _enabled = false;
    _generation++;
    _activePriority = null;
    _activeStartedAt = null;
    await _tts.stop();
  }
}
