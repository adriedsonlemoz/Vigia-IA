import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

class SpeechService {
  final FlutterTts _tts = FlutterTts();
  Future<void> _queue = Future<void>.value();
  bool _enabled = true;
  bool _initialized = false;
  bool _languageInstalled = false;

  bool get enabled => _enabled;
  bool get languageInstalled => _languageInstalled;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final installed = await _tts.isLanguageInstalled('pt-BR');
      _languageInstalled = installed == true;
      if (_languageInstalled) {
        await _tts.setLanguage('pt-BR');
        await _tts.setSpeechRate(0.48);
        await _tts.setVolume(1.0);
        await _tts.setPitch(1.0);
        await _tts.awaitSpeakCompletion(true);
      }
    } catch (_) {
      _languageInstalled = false;
    } finally {
      _initialized = true;
    }
  }

  void setEnabled(bool value) {
    _enabled = value;
    if (!value) {
      unawaited(_tts.stop());
    }
  }

  Future<void> speakDetection(String displayLabel) =>
      speakDetections(<String>[displayLabel]);

  Future<void> speakMessage(String text) async {
    final normalized = text.trim();
    if (!_enabled || !_initialized || !_languageInstalled || normalized.isEmpty) {
      return;
    }
    _queue = _queue.then((_) async {
      if (!_enabled) return;
      try {
        await _tts.speak(normalized);
      } catch (_) {
        // Uma falha pontual do TTS nao deve interromper deteccoes futuras.
      }
    });
    await _queue;
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

    _queue = _queue.then((_) async {
      if (!_enabled) return;
      try {
        await _tts.speak(text);
      } catch (_) {
        // Uma falha pontual do TTS nao deve interromper deteccoes futuras.
      }
    });
    await _queue;
  }

  String _joinLabels(List<String> labels) {
    if (labels.length == 2) return '${labels[0]} e ${labels[1]}';
    return '${labels.sublist(0, labels.length - 1).join(', ')} e ${labels.last}';
  }

  Future<void> dispose() async {
    _enabled = false;
    await _tts.stop();
  }
}
