import 'alert_voice_service.dart';
import 'app_settings_service.dart';
import 'speech_service.dart';

/// Ponte única de voz usada pelos recursos do mapa.
///
/// Reutiliza o coordenador de áudio/TTS do Vigia IA e respeita as preferências
/// globais de voz (incluindo TTS dinâmico) antes de falar instruções variáveis.
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
  }) async {
    final text = message.trim();
    if (text.isEmpty) return;
    await initialize();

    final monitorSettings = _settings.profile.settings;
    if (!monitorSettings.alertOutputs.voice) return;

    _voice.configure(monitorSettings.voiceAlertPreferences);
    if (!_voice.enabled) _voice.setEnabled(true);
    await _voice.deliver(text, priority: priority);
  }
}
