import 'alert_voice_service.dart';
import 'app_settings_service.dart';
import 'speech_service.dart';

/// Ponte única de voz usada pelos recursos do mapa.
///
/// Reutiliza o coordenador de áudio/TTS do Vigia IA e as preferências de TTS.
/// Chamadores podem manter a chave global como mestre ou usar um canal próprio,
/// como navegação e pontos próximos, que possuem controles independentes.
class MapVoiceService {
  MapVoiceService._();

  static final MapVoiceService instance = MapVoiceService._();

  final AlertVoiceService _voice = AlertVoiceService();
  final AppSettingsService _settings = AppSettingsService.instance;
  Future<void>? _initializing;
  bool _initialized = false;

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    final pending = _initializing;
    if (pending != null) return pending;
    final operation = _initializeInternal();
    _initializing = operation;
    return operation.whenComplete(() => _initializing = null);
  }

  Future<void> _initializeInternal() async {
    if (_initialized) return;
    await _settings.initialize();
    await _voice.initialize();
    _initialized = true;
  }

  Future<void> deliver(
    String message, {
    SpeechPriority priority = SpeechPriority.normal,
    bool respectGlobalVoice = true,
  }) async {
    final text = message.trim();
    if (text.isEmpty) return;
    await initialize();

    final monitorSettings = _settings.profile.settings;
    if (respectGlobalVoice && !monitorSettings.alertOutputs.voice) return;

    _voice.configure(monitorSettings.voiceAlertPreferences);
    if (!_voice.enabled) _voice.setEnabled(true);
    await _voice.deliver(text, priority: priority);
  }

  Future<void> stop() async {
    await initialize();
    await _voice.stop();
  }
}
