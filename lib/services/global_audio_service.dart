import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/alert_preferences.dart';
import '../models/audio_slot.dart';
import 'alert_voice_service.dart';
import 'app_settings_service.dart';
import 'native_platform_service.dart';
import 'speech_service.dart';

class GlobalAudioDiagnostics {
  const GlobalAudioDiagnostics({
    required this.ttsAvailable,
    required this.playerAvailable,
    required this.audioFocus,
    required this.output,
    required this.mediaVolume,
    required this.mediaMaxVolume,
    required this.mediaMuted,
    required this.globalVoiceEnabled,
    required this.playerState,
    this.lastError,
  });

  final bool ttsAvailable;
  final bool playerAvailable;
  final String audioFocus;
  final String output;
  final int mediaVolume;
  final int mediaMaxVolume;
  final bool mediaMuted;
  final bool globalVoiceEnabled;
  final String playerState;
  final String? lastError;

  double get volumeFraction => mediaMaxVolume <= 0
      ? 0
      : (mediaVolume / mediaMaxVolume).clamp(0.0, 1.0).toDouble();

  Map<String, Object?> toMap() => <String, Object?>{
        'ttsAvailable': ttsAvailable,
        'playerAvailable': playerAvailable,
        'audioFocus': audioFocus,
        'currentOutput': output,
        'mediaVolume': mediaVolume,
        'mediaMaxVolume': mediaMaxVolume,
        'mediaMuted': mediaMuted,
        'globalVoiceEnabled': globalVoiceEnabled,
        'playerState': playerState,
        'globalAudioLastError': lastError,
      };
}

/// Único coordenador de TTS, alertas gravados e diagnóstico de áudio do app.
/// Cada recurso pode falhar sem desativar os demais.
class GlobalAudioService extends ChangeNotifier with WidgetsBindingObserver {
  GlobalAudioService._();

  static final GlobalAudioService instance = GlobalAudioService._();

  final SpeechService _speech = SpeechService();
  late final AlertVoiceService _voice = AlertVoiceService(speech: _speech);
  final NativePlatformService _native = NativePlatformService.instance;
  final AppSettingsService _settings = AppSettingsService.instance;
  Future<void>? _initializing;
  bool _initialized = false;
  GlobalAudioDiagnostics? _diagnostics;

  bool get enabled => _voice.enabled;
  bool get languageInstalled => _voice.languageInstalled;
  GlobalAudioDiagnostics? get diagnostics => _diagnostics;

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initializing ??= _initializeInternal().whenComplete(
          () => _initializing = null,
        );
  }

  Future<void> _initializeInternal() async {
    if (_initialized) return;
    final profile = await _settings.initialize();
    await _voice.initialize();
    _voice.configure(profile.settings.voiceAlertPreferences);
    _voice.setEnabled(profile.settings.alertOutputs.voice);
    WidgetsBinding.instance.addObserver(this);
    _initialized = true;
    await refreshDiagnostics();
  }

  void configure(VoiceAlertPreferences preferences) =>
      _voice.configure(preferences);

  void setEnabled(bool enabled) {
    _voice.setEnabled(enabled);
    unawaited(refreshDiagnostics());
  }

  Future<void> deliver(
    String text, {
    String? audioSlot,
    SpeechPriority priority = SpeechPriority.normal,
    DateTime? capturedAt,
  }) async {
    try {
      await initialize();
      await _voice.deliver(
        text,
        audioSlot: audioSlot,
        priority: priority,
        capturedAt: capturedAt,
      );
    } catch (_) {
      // Uma falha de entrega não pode bloquear câmera, mapa ou alertas futuros.
    } finally {
      unawaited(refreshDiagnostics());
    }
  }

  Future<void> stop() async {
    try {
      await _voice.stop();
    } catch (_) {}
  }

  /// Compatibilidade com clientes de tela: libera a reprodução atual, mas o
  /// coordenador global continua vivo para os demais módulos.
  Future<void> disposeClient() => stop();

  Future<GlobalAudioDiagnostics> refreshDiagnostics() async {
    final native = await _native.audioDiagnostics();
    final current = GlobalAudioDiagnostics(
      ttsAvailable: _speech.initialized && _speech.languageInstalled,
      playerAvailable: native['channelError'] == null &&
          ((native['bundledResourceCount'] as num?)?.toInt() ?? 0) > 0,
      audioFocus: native['lastFocusResultName']?.toString() ?? 'Não solicitado',
      output: _outputLabel(native),
      mediaVolume: (native['mediaVolume'] as num?)?.toInt() ?? 0,
      mediaMaxVolume: (native['mediaMaxVolume'] as num?)?.toInt() ?? 0,
      mediaMuted: native['mediaMuted'] == true,
      globalVoiceEnabled: enabled,
      playerState: native['state']?.toString() ?? 'indisponível',
      lastError: _speech.lastError ??
          native['lastError']?.toString() ??
          native['channelError']?.toString(),
    );
    _diagnostics = current;
    notifyListeners();
    return current;
  }

  Future<bool> testAudio() async {
    await initialize();
    var playerOk = false;
    try {
      playerOk = await _native.playCustomAlertAudio(
        AudioSlotIds.objectDetected,
        priority: 2,
      );
    } catch (_) {}
    if (!playerOk && _speech.languageInstalled) {
      try {
        await _speech.speakMessage(
          'Teste de áudio do Vigia IA.',
          priority: SpeechPriority.high,
        );
      } catch (_) {}
    }
    final result = await refreshDiagnostics();
    return playerOk || result.ttsAvailable;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_recoverAfterResume());
    }
  }

  Future<void> _recoverAfterResume() async {
    try {
      await _speech.recoverAfterResume();
    } catch (_) {}
    await refreshDiagnostics();
  }

  String _outputLabel(Map<String, Object?> native) {
    final values = (native['availableOutputTypes'] as List?)
            ?.whereType<num>()
            .map((value) => value.toInt())
            .toSet() ??
        const <int>{};
    if (values.any((value) => const <int>{7, 8, 26, 27}.contains(value))) {
      return 'Bluetooth';
    }
    if (values.any((value) => const <int>{3, 4, 22}.contains(value))) {
      return 'Fone de ouvido';
    }
    if (values.contains(2)) return 'Alto-falante';
    if (native['speakerphoneOn'] == true) return 'Alto-falante';
    return values.isEmpty ? 'Indisponível' : 'Saída do sistema';
  }
}
